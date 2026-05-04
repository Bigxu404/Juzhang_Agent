import express from 'express';
import multer from 'multer';
import path from 'path';
import fs from 'fs';
import { prisma } from '../utils/db';

const router = express.Router();

// Ensure uploads directory exists
const uploadDir = path.join(__dirname, '../../uploads');
if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir, { recursive: true });
}

// Configure multer storage
const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    cb(null, uploadDir);
  },
  filename: function (req, file, cb) {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    cb(null, uniqueSuffix + '-' + file.originalname);
  }
});

const upload = multer({ storage: storage });

router.post('/upload', upload.single('file'), async (req, res) => {
  try {
    const userId = (req as any).userId;
    const file = req.file;

    if (!file) {
      return res.status(400).json({ error: 'No file uploaded' });
    }

    const { sessionId } = req.body;

    const fileRecord = await prisma.file.create({
      data: {
        userId,
        sessionId: sessionId || null,
        filename: file.originalname,
        mimeType: file.mimetype,
        localPath: file.path,
        url: `/uploads/${file.filename}`, // Local URL for downloading
        size: file.size,
      }
    });

    res.json({ success: true, file: fileRecord });
  } catch (error) {
    console.error('[Upload API] Error:', error);
    res.status(500).json({ error: 'Upload failed' });
  }
});

export const filesRouter = router;
