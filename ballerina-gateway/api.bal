import ballerina/email;
import ballerina/http;
import ballerina/io;
import ballerina/sql;
import ballerina/time;
import ballerina/uuid;
import ballerinax/postgresql;

import equihire/gateway.database;
import equihire/gateway.email as emailUtils;

// Imports from modules
import equihire/gateway.types;

// --- Configuration ---

configurable types:DatabaseConfig database = ?;
configurable string frontendUrl = ?;

// SMTP Configuration
configurable string smtpHost = ?;
configurable int smtpPort = ?;
configurable string smtpUsername = ?;
configurable string smtpPassword = ?;
configurable string smtpFromEmail = ?;

// --- Clients ---

final email:SmtpClient smtpClient = check new (
    host = smtpHost,
    username = smtpUsername,
    password = smtpPassword,
    port = smtpPort,
    security = email:START_TLS_AUTO
);

final postgresql:Client dbClient = check database:initClient(database);

// --- HTTP Service for API (Port 9092) ---
listener http:Listener apiListener = new (9092);

# REST API Service for EquiHire Platform.
# Exposes endpoints for Organization management, Interviews, and Invitations.
@http:ServiceConfig {
    cors: {
        allowOrigins: ["*"],
        allowCredentials: true,
        allowHeaders: ["Content-Type", "Authorization"]
    }
}
service /api on apiListener {

    resource function post organizations(@http:Payload types:OrganizationRequest payload) returns http:Created|error {
        io:println("NEW ORGANIZATION REGISTRATION REQUEST RECEIVED");

        // Transaction to ensure both Organization and Recruiter are created, or neither
        transaction {
            // 1. Insert Organization
            string orgId = check database:createOrganization(dbClient, payload.name, payload.industry, payload.size);

            io:println("Organization Created: ", orgId);

            // 2. Insert Recruiter (User) linked to Organization
            check database:createRecruiter(dbClient, payload.userId, payload.userEmail, orgId);

            // Transaction auto-commits at the end of the block if successful
            check commit;
        }

        return http:CREATED;
    }

    resource function get me/organization(string userId) returns types:OrganizationResponse|http:NotFound|error {
        return database:getOrganizationByUser(dbClient, userId);
    }

    resource function put organization(@http:Payload types:OrganizationResponse payload, string userId) returns http:Ok|http:Forbidden|error {
        // Security check: Ensure the user belongs to this organization
        boolean|error belongs = database:checkUserInOrganization(dbClient, userId, payload.id);
        if belongs is error {
            return belongs;
        }
        if !belongs {
            return http:FORBIDDEN;
        }

        error? updateResult = database:updateOrganization(dbClient, payload.id, payload.industry, payload.size);
        if updateResult is error {
            return error("Failed to update organization");
        }

        return http:OK;
    }

    // --- Magic Link Invitation Endpoints ---

    resource function post invitations(@http:Payload types:InvitationRequest payload) returns types:InvitationResponse|http:InternalServerError|error {
        io:println("NEW INTERVIEW INVITATION REQUEST");

        // 1. Resolve Recruiter ID
        string|sql:NoRowsError|sql:Error recruiterIdResult = database:getRecruiterId(dbClient, payload.recruiterId);

        if recruiterIdResult is sql:NoRowsError {
            io:println("Recruiter not found for User ID: ", payload.recruiterId);
            return error("Recruiter profile not found. Please log in again.");
        }
        if recruiterIdResult is sql:Error {
            io:println("Database error looking up recruiter: ", recruiterIdResult.message());
            return http:INTERNAL_SERVER_ERROR;
        }

        string realRecruiterId = <string>recruiterIdResult;

        // Generate unique token
        string token = uuid:createType1AsString();

        // Calculate expiration (7 days from now)
        time:Utc currentTime = time:utcNow();
        time:Utc expirationTime = time:utcAddSeconds(currentTime, 7 * 24 * 60 * 60); // 7 days
        string expiresAt = time:utcToString(expirationTime);

        // Insert invitation
        string|error invitationId = database:createInvitation(
                dbClient,
                token,
                payload.candidateEmail,
                payload.candidateName,
                payload.jobTitle,
                realRecruiterId,
                payload.organizationId,
                payload.interviewDate,
                expiresAt
        );

        if invitationId is error {
            io:println("Database error:", invitationId);
            return http:INTERNAL_SERVER_ERROR;
        }

        io:println("Invitation created with ID:", invitationId);

        // Generate magic link
        string magicLink = frontendUrl + "/invite/" + token;

        // Send email (SMTP)
        error? emailResult = emailUtils:sendInvitationEmail(
                smtpClient,
                smtpFromEmail,
                payload.candidateEmail,
                payload.candidateName,
                payload.jobTitle,
                magicLink
        );

        if emailResult is error {
            io:println("Email sending failed:", emailResult.message());
        } else {
            io:println("Invitation email sent to:", payload.candidateEmail);
        }

        return {
            id: invitationId,
            token: token,
            magicLink: magicLink,
            candidateEmail: payload.candidateEmail,
            expiresAt: expiresAt
        };
    }

    resource function get invitations/validate/[string token]() returns types:TokenValidationResponse|http:NotFound|error {
        io:println("Validating token:", token);

        // Query invitation by token
        database:InvitationRecord|sql:NoRowsError|sql:Error result = database:getInvitationByToken(dbClient, token);

        if result is sql:NoRowsError {
            return http:NOT_FOUND;
        }

        if result is sql:Error {
            return error("Database error during token validation");
        }

        // Check if already used
        if result.used_at !is () {
            return {
                valid: false,
                message: "This invitation link has already been used"
            };
        }

        // Check if expired
        string cleanExpiresAt = re ` `.replace(result.expires_at, "T");
        if !cleanExpiresAt.endsWith("Z") && !cleanExpiresAt.includes("+") {
            cleanExpiresAt = cleanExpiresAt + "Z";
        }

        time:Utc|error expirationTime = time:utcFromString(cleanExpiresAt);
        if expirationTime is error {
            io:println("Error parsing time: ", cleanExpiresAt);
            return error("Invalid expiration time format: " + cleanExpiresAt);
        }

        time:Utc currentTime = time:utcNow();
        decimal timeDiff = time:utcDiffSeconds(currentTime, expirationTime);
        if timeDiff > 0d {
            // Update status to expired
            _ = check database:expireInvitation(dbClient, result.id);

            return {
                valid: false,
                message: "This invitation link has expired"
            };
        }

        // Mark as used
        time:Utc usedTime = time:utcNow();
        string usedAtStr = time:utcToString(usedTime);
        _ = check database:acceptInvitation(dbClient, result.id, usedAtStr);

        io:println("Token validated successfully for:", result.candidate_email);

        return {
            valid: true,
            candidateEmail: result.candidate_email,
            candidateName: result.candidate_name,
            jobTitle: result.job_title,
            organizationId: result.organization_id
        };
    }
}

