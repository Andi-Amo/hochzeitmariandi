// Cloudinary connection settings for photo uploads.
//
// Firebase Storage now requires the paid "Blaze" plan even for tiny/free
// usage (a Google policy change), and Blaze billing-account verification
// can take a few days. Cloudinary offers a genuinely free tier (~25 GB
// storage/bandwidth) with no billing verification, so photo uploads use it
// instead. Firestore/Auth (guest list, RSVP, cakes, program items) keep
// using Firebase's free Spark plan unaffected.
//
// Setup (one-time, in the Cloudinary console at https://cloudinary.com):
//   1. Create a free account (no credit card required).
//   2. Your "Cloud name" is shown on the dashboard — put it below.
//   3. Go to Settings → Upload → Upload presets → "Add upload preset".
//      Set "Signing Mode" to "Unsigned" (so the app can upload directly
//      without a server-side secret) and save. Put the preset name below.
class CloudinaryConfig {
  CloudinaryConfig._();

  static const String cloudName = 'emdhcka7';
  static const String unsignedUploadPreset = 'wedapp';
}
