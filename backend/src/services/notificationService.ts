export const sendWhatsApp = async (to: string, message: string): Promise<void> => {
  if (!process.env.TWILIO_AUTH_TOKEN) {
    console.log(`[MOCK] WhatsApp to ${to}: ${message}`);
    return;
  }
  // Real implementation would go here
};

export const sendEmail = async (to: string, subject: string, body: string): Promise<void> => {
  if (!process.env.SENDGRID_API_KEY) {
    console.log(`[MOCK] Email to ${to}: ${subject}`);
    return;
  }
};
