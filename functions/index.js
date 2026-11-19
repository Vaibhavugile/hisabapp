
const {setGlobalOptions} = require('firebase-functions');
const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {defineSecret} = require('firebase-functions/params');
const logger = require('firebase-functions/logger');
const admin = require('firebase-admin');
const crypto = require('crypto');

admin.initializeApp();

setGlobalOptions({
  region: 'asia-south1',
  maxInstances: 10,
});

const MSG91_AUTHKEY = defineSecret('MSG91_AUTHKEY');

const db = admin.firestore();
const auth = admin.auth();

// MSG91 configuration
const MSG91_URL =
  'https://api.msg91.com/api/v5/whatsapp/whatsapp-outbound-message/bulk/';

const MSG91_INTEGRATED_NUMBER = '15558299861';
const MSG91_TEMPLATE = 'kiyuotp';
const MSG91_LANGUAGE = 'en';
const MSG91_NAMESPACE =
  '60cbb046_c34d_4f04_8c62_2cb720ccf00d';

// OTP configuration
const OTP_EXPIRY_MS = 60 * 1000;
const RESEND_COOLDOWN_MS = 60 * 1000;
const MAX_VERIFY_ATTEMPTS = 5;

// --------------------------------------------------
// PHONE NUMBER NORMALIZATION
// --------------------------------------------------

function normalizePhone(value) {
  if (typeof value !== 'string') {
    throw new HttpsError(
        'invalid-argument',
        'Phone number is required.',
    );
  }

  const phone = value.replace(/[^\d+]/g, '');

  if (!/^\+[1-9]\d{7,14}$/.test(phone)) {
    throw new HttpsError(
        'invalid-argument',
        'Enter a valid phone number with country code, e.g. +919876543210.',
    );
  }

  return phone;
}

// --------------------------------------------------
// SECURE PHONE DOCUMENT KEY
// --------------------------------------------------

function phoneKey(phone) {
  return crypto
      .createHash('sha256')
      .update(phone)
      .digest('hex');
}

// --------------------------------------------------
// OTP HASH
// --------------------------------------------------

function otpHash(phone, otp) {
  return crypto
      .createHmac('sha256', MSG91_AUTHKEY.value())
      .update(phone + ':' + otp)
      .digest('hex');
}

// --------------------------------------------------
// CONSTANT-TIME HASH COMPARISON
// --------------------------------------------------

function safeHashCompare(hash1, hash2) {
  const first = Buffer.from(hash1, 'hex');
  const second = Buffer.from(hash2, 'hex');

  if (first.length !== second.length) {
    return false;
  }

  return crypto.timingSafeEqual(first, second);
}

// --------------------------------------------------
// SEND MSG91 WHATSAPP OTP
// --------------------------------------------------

async function sendMsg91WhatsApp(phone, otp) {
  const payload = {
    integrated_number: MSG91_INTEGRATED_NUMBER,
    content_type: 'template',
    payload: {
      messaging_product: 'whatsapp',
      type: 'template',
      template: {
        name: MSG91_TEMPLATE,
        language: {
          code: MSG91_LANGUAGE,
          policy: 'deterministic',
        },
        namespace: MSG91_NAMESPACE,
        to_and_components: [
          {
            to: [phone.replace('+', '')],
            components: {
              body_1: {
                type: 'text',
                value: otp,
              },
              button_1: {
                subtype: 'url',
                type: 'text',
                value: otp,
              },
            },
          },
        ],
      },
    },
  };

  const response = await fetch(MSG91_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'authkey': MSG91_AUTHKEY.value(),
    },
    body: JSON.stringify(payload),
  });

  const responseText = await response.text();

  let result;

  try {
    result = JSON.parse(responseText);
  } catch (error) {
    result = {
      message: responseText,
    };
  }

  if (
    !response.ok ||
    result.status === 'error' ||
    result.hasError === true
  ) {
    logger.error('MSG91 WhatsApp send failed', {
      status: response.status,
      response: result,
    });

    throw new HttpsError(
        'unavailable',
        'Unable to send WhatsApp OTP. Please try again.',
    );
  }

  logger.info('MSG91 WhatsApp request accepted', {
    status: response.status,
  });

  return result;
}

// --------------------------------------------------
// SEND WHATSAPP OTP
// --------------------------------------------------

exports.sendWhatsAppOtp = onCall(
    {
      secrets: [MSG91_AUTHKEY],
      enforceAppCheck: false,
    },
    async (request) => {
      const data = request.data || {};
      const phone = normalizePhone(data.phone);

      const key = phoneKey(phone);

      const ref = db
          .collection('whatsappOtpChallenges')
          .doc(key);

      const now = Date.now();

      const otp = crypto
          .randomInt(100000, 1000000)
          .toString();

      // Create OTP challenge with resend protection.
      await db.runTransaction(async (transaction) => {
        const snapshot = await transaction.get(ref);

        if (snapshot.exists) {
          const previous = snapshot.data();

          if (
            previous.lastSentAt &&
          now - previous.lastSentAt.toMillis() <
            RESEND_COOLDOWN_MS
          ) {
            throw new HttpsError(
                'resource-exhausted',
                'Please wait one minute before requesting another OTP.',
            );
          }
        }

        transaction.set(ref, {
          phone: phone,
          otpHash: otpHash(phone, otp),

          createdAt:
          admin.firestore.Timestamp.fromMillis(now),

          expiresAt:
          admin.firestore.Timestamp.fromMillis(
              now + OTP_EXPIRY_MS,
          ),

          lastSentAt:
          admin.firestore.Timestamp.fromMillis(now),

          attempts: 0,
          verified: false,
        });
      });

      // Send OTP using MSG91.
      try {
        await sendMsg91WhatsApp(phone, otp);
      } catch (error) {
        await ref.delete().catch(() => {});

        if (error instanceof HttpsError) {
          throw error;
        }

        logger.error('WhatsApp OTP sending error', error);

        throw new HttpsError(
            'unavailable',
            'Unable to send OTP. Please try again.',
        );
      }

      return {
        success: true,
        message: 'OTP sent to your WhatsApp number.',
        expiresInSeconds: 60,
      };
    },
);

// --------------------------------------------------
// VERIFY WHATSAPP OTP
// --------------------------------------------------

exports.verifyWhatsAppOtp = onCall(
    {
      secrets: [MSG91_AUTHKEY],
      enforceAppCheck: false,
    },
    async (request) => {
      const data = request.data || {};

      const phone = normalizePhone(data.phone);

      const otp = String(data.otp || '').trim();

      if (!/^\d{6}$/.test(otp)) {
        throw new HttpsError(
            'invalid-argument',
            'Enter the valid six-digit OTP.',
        );
      }

      const key = phoneKey(phone);

      const ref = db
          .collection('whatsappOtpChallenges')
          .doc(key);

      const suppliedHash = otpHash(phone, otp);

      // IMPORTANT:
      // Return error codes from the transaction instead of
      // throwing inside it, so incorrect-attempt updates commit.
      const verificationResult = await db.runTransaction(
          async (transaction) => {
            const snapshot = await transaction.get(ref);

            if (!snapshot.exists) {
              return 'NOT_FOUND';
            }

            const challenge = snapshot.data();

            if (challenge.verified === true) {
              return 'USED';
            }

            if (
              challenge.expiresAt.toMillis() < Date.now()
            ) {
              transaction.delete(ref);
              return 'EXPIRED';
            }

            if (
              challenge.attempts >= MAX_VERIFY_ATTEMPTS
            ) {
              transaction.delete(ref);
              return 'TOO_MANY';
            }

            if (
              !safeHashCompare(
                  challenge.otpHash,
                  suppliedHash,
              )
            ) {
              const nextAttempts = challenge.attempts + 1;

              if (nextAttempts >= MAX_VERIFY_ATTEMPTS) {
                transaction.delete(ref);
                return 'TOO_MANY';
              }

              transaction.update(ref, {
                attempts: nextAttempts,
              });

              return 'INCORRECT';
            }

            transaction.update(ref, {
              verified: true,

              verifiedAt:
            admin.firestore.FieldValue.serverTimestamp(),
            });

            return 'VERIFIED';
          },
      );

      const verificationErrors = {
        NOT_FOUND: [
          'not-found',
          'OTP not found. Please request a new OTP.',
        ],

        USED: [
          'failed-precondition',
          'This OTP has already been used.',
        ],

        EXPIRED: [
          'deadline-exceeded',
          'OTP expired. Please request a new OTP.',
        ],

        TOO_MANY: [
          'resource-exhausted',
          'Too many incorrect attempts. Request a new OTP.',
        ],

        INCORRECT: [
          'permission-denied',
          'Incorrect OTP. Please try again.',
        ],
      };

      if (verificationResult !== 'VERIFIED') {
        const errorDetails =
        verificationErrors[verificationResult];

        throw new HttpsError(
            errorDetails[0],
            errorDetails[1],
        );
      }

      // --------------------------------------------------
      // FIND OR CREATE FIREBASE USER
      // --------------------------------------------------

      let user;

      try {
        user = await auth.getUserByPhoneNumber(phone);
      } catch (error) {
        if (error.code !== 'auth/user-not-found') {
          logger.error('Firebase user lookup failed', error);

          throw new HttpsError(
              'internal',
              'Unable to authenticate user.',
          );
        }

        try {
          user = await auth.createUser({
            phoneNumber: phone,
          });
        } catch (createError) {
          if (
            createError.code ===
          'auth/phone-number-already-exists'
          ) {
            user = await auth.getUserByPhoneNumber(phone);
          } else {
            logger.error(
                'Firebase user creation failed',
                createError,
            );

            throw new HttpsError(
                'internal',
                'Unable to create user account.',
            );
          }
        }
      }

      // --------------------------------------------------
      // GENERATE FIREBASE CUSTOM TOKEN
      // --------------------------------------------------

      const customToken = await auth.createCustomToken(
          user.uid,
      );

      // --------------------------------------------------
      // AUTOMATIC SHARED ACCOUNT LINKING
      // --------------------------------------------------

      const accountQuery = await db
          .collection('accounts')
          .where('isShared', '==', true)
          .where('phoneNormalized', '==', phone)
          .get();

      const accountDocs = accountQuery.docs;

      // Firestore batch limit is 500 writes.
      // Use smaller batches to support multiple accounts.
      const batchSize = 400;

      for (
        let start = 0;
        start < accountDocs.length;
        start += batchSize
      ) {
        const batch = db.batch();

        const currentDocs = accountDocs.slice(
            start,
            start + batchSize,
        );

        for (const accountDoc of currentDocs) {
          const account = accountDoc.data();

          // Do not link the owner to their own account.
          if (account.ownerId === user.uid) {
            continue;
          }

          // Do not replace an account already linked
          // to a different user.
          if (
            account.linkedUserId &&
          account.linkedUserId !== user.uid
          ) {
            logger.warn(
                'Shared account already linked to another user',
                {
                  accountId: accountDoc.id,
                },
            );

            continue;
          }

          const members = Array.isArray(account.memberIds) ?
          account.memberIds.slice() :
          [];

          if (!members.includes(user.uid)) {
            members.push(user.uid);
          }

          batch.update(accountDoc.ref, {
            linkedUserId: user.uid,
            memberIds: members,

            updatedAt:
            admin.firestore.FieldValue.serverTimestamp(),
          });
        }

        await batch.commit();
      }

      // --------------------------------------------------
      // DELETE USED OTP
      // --------------------------------------------------

      await ref.delete();

      logger.info('WhatsApp OTP verification successful', {
        uid: user.uid,
      });

      return {
        success: true,
        message: 'Phone number verified successfully.',
        customToken: customToken,
        uid: user.uid,
        phoneNumber: phone,
      };
    },
);
