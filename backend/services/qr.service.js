const QRCode = require('qrcode');
const { generateRandomToken } = require('../utils/helpers');

async function generateQRCode(tableId, token, baseUrl = '') {
  const qrData = `${baseUrl}/customer/table/${token}`;
  const qrImage = await QRCode.toDataURL(qrData, {
    width: 300,
    margin: 2,
    color: {
      dark: '#000000',
      light: '#FFFFFF'
    }
  });
  return { qrImage, qrData, token };
}

function generateNewToken() {
  return generateRandomToken(16);
}

module.exports = {
  generateQRCode,
  generateNewToken
};
