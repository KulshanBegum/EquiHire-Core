import ballerina/email;

# Sends an invitation email to a candidate using the configured SMTP server.
#
# + smtpClient - The SMTP client to use for sending
# + fromEmail - The email address to send from
# + toEmail - The candidate's email address
# + candidateName - The name of the candidate
# + jobTitle - The job title for the interview
# + magicLink - The unique link for the interview
# + return - An error if sending fails, otherwise nil
public function sendInvitationEmail(email:SmtpClient smtpClient, string fromEmail, string toEmail, string candidateName, string jobTitle, string magicLink) returns error? {

    // HTML Template
    string htmlBody = string `
        <!DOCTYPE html>
        <html>
        <head>
            <style>
                body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; line-height: 1.6; color: #333; }
                .container { max-width: 600px; margin: 0 auto; padding: 20px; }
                .header { background: linear-gradient(135deg, #FF7300 0%, #E56700 100%); color: white; padding: 30px; text-align: center; border-radius: 8px 8px 0 0; }
                .content { background: #ffffff; padding: 30px; border: 1px solid #e0e0e0; border-top: none; }
                .button { display: inline-block; background: #FF7300; color: white; padding: 14px 32px; text-decoration: none; border-radius: 6px; font-weight: 600; margin: 20px 0; }
                .button:hover { background: #E56700; }
                .footer { text-align: center; padding: 20px; color: #666; font-size: 12px; }
                .info-box { background: #f9f9f9; border-left: 4px solid #FF7300; padding: 15px; margin: 20px 0; }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h1 style="margin: 0; font-size: 28px;">🎯 EquiHire</h1>
                    <p style="margin: 10px 0 0 0; opacity: 0.95;">Blind Interview Platform</p>
                </div>
                <div class="content">
                    <h2 style="color: #FF7300; margin-top: 0;">Hello ${candidateName},</h2>
                    <p>You have been invited to participate in a <strong>Blind Interview</strong> for the position of:</p>
                    <div class="info-box">
                        <h3 style="margin: 0; color: #FF7300;">${jobTitle}</h3>
                    </div>
                    <p>EquiHire ensures a fair and unbiased interview process. Your identity will be protected to ensure evaluation based purely on technical merit.</p>
                    <p><strong>Click the button below to access your interview:</strong></p>
                    <div style="text-align: center;">
                        <a href="${magicLink}" class="button">Join Interview →</a>
                    </div>
                    <p style="font-size: 13px; color: #666; margin-top: 30px;">
                        <strong>Note:</strong> This link is valid for 7 days and can only be used once. If you did not request this interview, please ignore this email.
                    </p>
                    <p style="font-size: 12px; color: #999; margin-top: 20px;">
                        If the button doesn't work, copy and paste this link:<br>
                        <span style="color: #FF7300; word-break: break-all;">${magicLink}</span>
                    </p>
                </div>
                <div class="footer">
                    <p>Powered by <strong>EquiHire Core</strong> • Privacy Protected</p>
                    <p>Evaluating Code, Not Context.</p>
                </div>
            </div>
        </body>
        </html>
    `;

    email:Message emailMessage = {
        to: toEmail,
        subject: "Your Interview Invitation - " + jobTitle,
        htmlBody: htmlBody,
        'from: fromEmail
    };

    check smtpClient->sendMessage(emailMessage);
    return;
}
