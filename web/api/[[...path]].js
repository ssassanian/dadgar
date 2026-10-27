'use strict';
/* ورودی API سرورلس — فقط از مسیر /api/* (filesystem route) صدا زده می‌شود.
   پورت CMD-002؛ منطق کامل در ../lib/web.js */
const { apiEntry } = require('../lib/web');
module.exports = async (req, res) => apiEntry(req, res);
module.exports.config = { maxDuration: 30 };
