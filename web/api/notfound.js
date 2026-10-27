'use strict';
/* ورودی ۴۰۴ — هر مسیر ناشناخته غیر از /api/* و / به اینجا ریرایت می‌شود (مثل رفتار اصلی). */
const { notFoundEntry } = require('../lib/web');
module.exports = async (req, res) => notFoundEntry(req, res);
module.exports.config = { maxDuration: 10 };
