const sharp = require('sharp');
const { v4: uuidv4 } = require('uuid');
const path = require('path');
const os = require('os');
const fs = require('fs');

// ═══════════════════════════════════════════════════════════════════════════════
// PHASE C1 — MEDIA OPTIMIZATION PIPELINE
// ═══════════════════════════════════════════════════════════════════════════════

exports.onMediaUpload = functions.storage.object().onFinalize(async (object) => {
  const filePath = object.name;
  const contentType = object.contentType;
  const customMetadata = object.metadata || {};

  // Only process images (skip WebP if it's already optimized to prevent loops)
  if (!contentType.startsWith('image/') || filePath.endsWith('_1080x1080.webp')) {
    return null;
  }

  // Only process if we have a target document to update
  const targetDoc = customMetadata.targetDoc;
  const targetField = customMetadata.targetField || 'optimizedImagePaths';
  
  if (!targetDoc) {
    console.log(`Skipping ${filePath} - No targetDoc metadata`);
    return null;
  }

  const bucket = admin.storage().bucket(object.bucket);
  const fileName = path.basename(filePath);
  const tempFilePath = path.join(os.tmpdir(), fileName);
  const optimizedFileName = fileName.replace(/\.[^/.]+$/, "") + '_1080x1080.webp';
  const optimizedFilePath = path.join(path.dirname(filePath), optimizedFileName);
  const tempOptimizedPath = path.join(os.tmpdir(), optimizedFileName);

  try {
    // 1. Download original image
    await bucket.file(filePath).download({ destination: tempFilePath });
    console.log(`Downloaded ${filePath} to ${tempFilePath}`);

    // 2. Resize and convert to WebP
    await sharp(tempFilePath)
      .resize(1080, 1080, { fit: 'inside', withoutEnlargement: true })
      .webp({ quality: 80 })
      .toFile(tempOptimizedPath);
    console.log(`Optimized image created at ${tempOptimizedPath}`);

    // 3. Generate persistent download token
    const downloadToken = uuidv4();

    // 4. Upload optimized image with the token
    await bucket.upload(tempOptimizedPath, {
      destination: optimizedFilePath,
      metadata: {
        contentType: 'image/webp',
        cacheControl: 'public, max-age=31536000, immutable',
        metadata: {
          firebaseStorageDownloadTokens: downloadToken,
        }
      }
    });

    // 5. Construct Firebase HTTP download URL
    const encodedPath = encodeURIComponent(optimizedFilePath).replace(/%2F/g, '/');
    const optimizedUrl = `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encodedPath}?alt=media&token=${downloadToken}`;
    console.log(`Optimized URL generated: ${optimizedUrl}`);

    // 6. Update Firestore Document
    const docRef = db.doc(targetDoc);
    
    // Depending on the field type, we update it
    if (targetField === 'optimizedImagePaths') {
      // Assuming it's an array
      await docRef.update({
        [targetField]: admin.firestore.FieldValue.arrayUnion(optimizedUrl)
      });
    } else {
      // Assuming it's a string
      await docRef.update({
        [targetField]: optimizedUrl
      });
    }
    
    console.log(`Updated Firestore document ${targetDoc} with optimized URL.`);

  } catch (error) {
    console.error(`Error processing ${filePath}:`, error);
  } finally {
    // Cleanup temp files
    if (fs.existsSync(tempFilePath)) fs.unlinkSync(tempFilePath);
    if (fs.existsSync(tempOptimizedPath)) fs.unlinkSync(tempOptimizedPath);
  }

  return null;
});
