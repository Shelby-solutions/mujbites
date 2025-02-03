const express = require('express');
const axios = require('axios');
const router = express.Router();

// Endpoint to verify reCAPTCHA
router.post('/verify-recaptcha', async (req, res) => {
  const { recaptchaToken } = req.body;

  // Log the request body for debugging
  console.log('Request Body:', req.body);

  if (!recaptchaToken) {
    return res.status(400).json({ success: false, message: 'reCAPTCHA token is required' });
  }

  try {
    // Verify the reCAPTCHA token with Google's API
    const response = await axios.post(
      `https://www.google.com/recaptcha/api/siteverify?secret=${process.env.RECAPTCHA_SECRET_KEY}&response=${recaptchaToken}`
    );

    // Log the Google reCAPTCHA API response for debugging
    console.log('Google reCAPTCHA API Response:', response.data);

    if (response.data.success) {
      // reCAPTCHA verification successful
      res.status(200).json({ success: true });
    } else {
      // reCAPTCHA verification failed
      res.status(400).json({ success: false, message: 'reCAPTCHA verification failed', details: response.data });
    }
  } catch (error) {
    console.error('reCAPTCHA verification error:', error);

    // Log the full error details
    if (error.response) {
      console.error('Google reCAPTCHA API response:', error.response.data);
    }

    res.status(500).json({ success: false, message: 'Internal server error', error: error.message });
  }
});

module.exports = router;