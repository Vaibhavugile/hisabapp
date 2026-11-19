
'use strict';

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
const MSG91_NAMESPACE = '60cbb046_c34d_4f04_8c62_2cb720ccf00d';

// OTP configuration
const OTP_EXPIRY_MS = 60 * 1000;
const RESEND_COOLDOWN_MS = 60 * 1000;
const MAX_VERIFY_ATTEMPTS = 5;

// -----------------------------------------------------------------------------
// PHONE NUMBER NORMALIZATION
// -----------------------------------------------------------------------------

function normalizePhone(value) {
  if (typeof value !== 'string') {
    throw new HttpsError('invalid-argument', 'Phone number is required.');
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

function phoneKey(phone) {
  return crypto.createHash('sha256').update(phone).digest('hex');
}

function otpHash(phone, otp) {
  return crypto
      .createHmac('sha256', MSG91_AUTHKEY.value())
      .update(`${phone}:${otp}`)
      .digest('hex');
}

function safeHashCompare(hash1, hash2) {
  if (typeof hash1 !== 'string' || typeof hash2 !== 'string') {
    return false;
  }

  const first = Buffer.from(hash1, 'hex');
  const second = Buffer.from(hash2, 'hex');

  if (first.length !== second.length || first.length === 0) {
    return false;
  }

  return crypto.timingSafeEqual(first, second);
}

function getAccountInvitedPhone(account) {
  return account.invitedPhoneNormalized ||
    account.phoneNormalized ||
    account.invitedPhone ||
    '';
}

// -----------------------------------------------------------------------------
// MSG91 WHATSAPP OTP
// -----------------------------------------------------------------------------

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
  } catch (_) {
    result = {message: responseText};
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

// -----------------------------------------------------------------------------
// LINK A VERIFIED USER TO AN INVITED SHARED ACCOUNT
// -----------------------------------------------------------------------------

async function linkUserToInvitedAccounts(phone, user) {
  const query = await db
      .collection('accounts')
      .where('isShared', '==', true)
      .where('phoneNormalized', '==', phone)
      .get();

  if (query.empty) return 0;

  let linkedCount = 0;
  const batchSize = 400;

  for (let start = 0; start < query.docs.length; start += batchSize) {
    const batch = db.batch();
    const docs = query.docs.slice(start, start + batchSize);
    let writes = 0;

    for (const accountDoc of docs) {
      const account = accountDoc.data();

      // Never link an owner to their own invitation.
      if (account.ownerId === user.uid) continue;

      // Do not overwrite a different linked user.
      if (
        account.linkedUserId &&
        account.linkedUserId !== user.uid
      ) {
        logger.warn('Shared account already linked to another user', {
          accountId: accountDoc.id,
        });

        continue;
      }

      // Confirm that the invited phone matches the verified phone.
      if (getAccountInvitedPhone(account) !== phone) continue;

      const memberIds = Array.isArray(account.memberIds) ?
        account.memberIds.map(String) :
        [];

      if (!memberIds.includes(user.uid)) {
        memberIds.push(user.uid);
      }

      batch.update(accountDoc.ref, {
        linkedUserId: user.uid,
        linkedUserName: user.displayName || user.phoneNumber || null,
        memberIds,
        isShared: true,
        sharingStatus: 'shared',
        joinedAt:
          account.joinedAt ||
          admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      writes++;
      linkedCount++;
    }

    if (writes > 0) {
      await batch.commit();
    }
  }

  return linkedCount;
}

// -----------------------------------------------------------------------------
// SEND WHATSAPP OTP
// -----------------------------------------------------------------------------

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

      await db.runTransaction(async (transaction) => {
        const snapshot = await transaction.get(ref);

        if (snapshot.exists) {
          const previous = snapshot.data();

          if (
            previous.lastSentAt &&
          now - previous.lastSentAt.toMillis() < RESEND_COOLDOWN_MS
          ) {
            throw new HttpsError(
                'resource-exhausted',
                'Please wait one minute before requesting another OTP.',
            );
          }
        }

        transaction.set(ref, {
          phone,
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

// -----------------------------------------------------------------------------
// VERIFY WHATSAPP OTP
// -----------------------------------------------------------------------------

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

      // Return status strings so failed-attempt updates are committed.
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

            if (challenge.expiresAt.toMillis() < Date.now()) {
              transaction.delete(ref);
              return 'EXPIRED';
            }

            if ((challenge.attempts || 0) >= MAX_VERIFY_ATTEMPTS) {
              transaction.delete(ref);
              return 'TOO_MANY';
            }

            if (!safeHashCompare(challenge.otpHash, suppliedHash)) {
              const nextAttempts = (challenge.attempts || 0) + 1;

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
        const details = verificationErrors[verificationResult];

        throw new HttpsError(
            details[0],
            details[1],
        );
      }

      // Find or create the Firebase user for this verified phone.
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
            createError.code === 'auth/phone-number-already-exists'
          ) {
            user = await auth.getUserByPhoneNumber(phone);
          } else {
            logger.error('Firebase user creation failed', createError);

            throw new HttpsError(
                'internal',
                'Unable to create user account.',
            );
          }
        }
      }

      // Link all shared accounts matching this verified phone.
      try {
        await linkUserToInvitedAccounts(phone, user);
      } catch (error) {
        logger.error('Automatic shared-account linking failed', {
          uid: user.uid,
          error,
        });

      // Authentication can still succeed if account linking needs retry.
      }

      // Generate Firebase custom token.
      const customToken = await auth.createCustomToken(user.uid);

      // Delete the used OTP.
      await ref.delete();

      logger.info('WhatsApp OTP verification successful', {
        uid: user.uid,
      });

      return {
        success: true,
        message: 'Phone number verified successfully.',
        customToken,
        uid: user.uid,
        phoneNumber: phone,
      };
    },
);

// -----------------------------------------------------------------------------
// LINK EXISTING REGISTERED USER WHEN OWNER CREATES A SHARED ACCOUNT
// -----------------------------------------------------------------------------

exports.linkExistingSharedAccount = onCall(
    {
      enforceAppCheck: false,
    },
    async (request) => {
      if (!request.auth) {
        throw new HttpsError(
            'unauthenticated',
            'Please log in first.',
        );
      }

      const ownerUid = request.auth.uid;

      const accountId = String(
          request.data?.accountId || '',
      ).trim();

      if (!accountId) {
        throw new HttpsError(
            'invalid-argument',
            'Account ID is required.',
        );
      }

      const accountRef = db
          .collection('accounts')
          .doc(accountId);

      const accountSnapshot = await accountRef.get();

      if (!accountSnapshot.exists) {
        throw new HttpsError(
            'not-found',
            'Account not found.',
        );
      }

      const account = accountSnapshot.data();

      // Only the account owner can initiate linking.
      if (account.ownerId !== ownerUid) {
        throw new HttpsError(
            'permission-denied',
            'Only the account owner can link a member.',
        );
      }

      if (account.isShared !== true) {
        throw new HttpsError(
            'failed-precondition',
            'This account is not configured as a shared account.',
        );
      }

      const invitedPhone = normalizePhone(
          account.invitedPhoneNormalized ||
      account.phoneNormalized ||
      account.phone,
      );

      // Find the registered Firebase user by the invited phone.
      let invitedUser;

      try {
        invitedUser = await auth.getUserByPhoneNumber(invitedPhone);
      } catch (error) {
        if (error.code === 'auth/user-not-found') {
          return {
            success: true,
            linked: false,
            status: 'waiting_for_user',
            message: 'The invited person has not registered yet.',
          };
        }

        logger.error('Invited user lookup failed', {
          accountId,
          error,
        });

        throw new HttpsError(
            'internal',
            'Unable to look up invited user.',
        );
      }

      if (invitedUser.uid === ownerUid) {
        throw new HttpsError(
            'failed-precondition',
            'You cannot share an account with your own phone number.',
        );
      }

      // Re-read and validate the account inside a transaction.
      await db.runTransaction(async (transaction) => {
        const latestSnapshot = await transaction.get(accountRef);

        if (!latestSnapshot.exists) {
          throw new HttpsError(
              'not-found',
              'Account not found.',
          );
        }

        const latest = latestSnapshot.data();

        if (
          latest.ownerId !== ownerUid ||
        latest.isShared !== true
        ) {
          throw new HttpsError(
              'permission-denied',
              'You are not allowed to link this account.',
          );
        }

        const latestPhone = normalizePhone(
            latest.invitedPhoneNormalized ||
        latest.phoneNormalized ||
        latest.phone,
        );

        if (latestPhone !== invitedPhone) {
          throw new HttpsError(
              'failed-precondition',
              'The invited phone number has changed. Please try again.',
          );
        }

        if (
          latest.linkedUserId &&
        latest.linkedUserId !== invitedUser.uid
        ) {
          throw new HttpsError(
              'already-exists',
              'This account is already linked to another user.',
          );
        }

        const memberIds = Array.isArray(latest.memberIds) ?
        latest.memberIds.map(String) :
        [ownerUid];

        if (!memberIds.includes(ownerUid)) {
          memberIds.push(ownerUid);
        }

        if (!memberIds.includes(invitedUser.uid)) {
          memberIds.push(invitedUser.uid);
        }

        transaction.update(accountRef, {
          isShared: true,

          linkedUserId: invitedUser.uid,

          linkedUserName:
          invitedUser.displayName ||
          invitedUser.phoneNumber ||
          null,

          memberIds,

          sharingStatus: 'shared',

          joinedAt:
          latest.joinedAt ||
          admin.firestore.FieldValue.serverTimestamp(),

          updatedAt:
          admin.firestore.FieldValue.serverTimestamp(),
        });
      });

      logger.info('Existing user linked to shared account', {
        accountId,
        ownerUid,
        memberUid: invitedUser.uid,
      });

      return {
        success: true,
        linked: true,
        status: 'shared',
        linkedUserId: invitedUser.uid,
        message: 'Existing user linked successfully.',
      };
    },
);
