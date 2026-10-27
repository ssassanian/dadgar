'use strict';
/* ورودی HTML — فقط «/» از طریق rewrite به اینجا می‌آید؛ index.html را با CSP nonce سرو می‌کند. */
const { htmlEntry } = require('../lib/web');
module.exports = async (req, res) => htmlEntry(req, res);
module.exports.config = { maxDuration: 10 };
