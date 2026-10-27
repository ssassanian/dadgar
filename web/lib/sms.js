'use strict';
// SMS adapter. No SMS panel is connected yet: the default "console" driver only prints the code in the server log.
// To go live, set SMS_DRIVER=http and adapt the request below to your provider (Kavenegar, Melipayamak, ...).
module.exports = async function sendSms(phone, text) {
  const driver = process.env.SMS_DRIVER || 'console';
  if (driver === 'console') { if (process.env.NODE_ENV !== 'test') console.log('[SMS:console] to ' + phone + ' -> ' + text); return true; }
  if (driver === 'http') {
    const url = process.env.SMS_URL, key = process.env.SMS_API_KEY;
    if (!url) throw new Error('SMS_URL is not configured');
    const r = await fetch(url, { method: 'POST', headers: { 'content-type': 'application/json', authorization: 'Bearer ' + (key || '') }, body: JSON.stringify({ to: phone, text }) });
    return r.ok;
  }
  throw new Error('Unknown SMS_DRIVER');
};
