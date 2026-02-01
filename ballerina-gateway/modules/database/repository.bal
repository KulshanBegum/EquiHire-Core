import ballerina/sql;
import ballerinax/postgresql;

import equihire/gateway.types; // Import types module

// --- Database Client ---
// We keep the client here.
// In a larger app, you might inject this client into the functions.

# Initializes the database client.
#
# + config - Database configuration
# + return - The initialized client or an error
public function initClient(types:DatabaseConfig config) returns postgresql:Client|error {
    return new (
        host = config.host,
        username = config.user,
        password = config.password,
        database = config.name,
        port = config.port
    );
}

// --- Repository Functions ---

# Creates a new organization in the database.
#
# + dbClient - Database client
# + name - Organization name
# + industry - Industry
# + size - Organization size
# + return - The ID of the created organization or an error
public function createOrganization(postgresql:Client dbClient, string name, string industry, string size) returns string|error {
    sql:ParameterizedQuery query = `INSERT INTO organizations (name, industry, size) 
                                     VALUES (${name}, ${industry}, ${size}) 
                                     RETURNING id`;
    return dbClient->queryRow(query);
}

# Creates a new recruiter (admin) for an organization.
#
# + dbClient - Database client
# + userId - User ID (UUID)
# + email - User email
# + organizationId - Organization ID (UUID)
# + return - Error if failed, else nil
public function createRecruiter(postgresql:Client dbClient, string userId, string email, string organizationId) returns error? {
    sql:ParameterizedQuery query = `INSERT INTO recruiters (user_id, email, organization_id, role) 
                                                   VALUES (${userId}::uuid, ${email}, ${organizationId}::uuid, 'admin')`;
    _ = check dbClient->execute(query);
    return;
}

# Retrieves organization details for a given user.
#
# + dbClient - Database client
# + userId - The user ID
# + return - Organization details or NotFound/Error
public function getOrganizationByUser(postgresql:Client dbClient, string userId) returns types:OrganizationResponse|sql:NoRowsError|sql:Error {
    sql:ParameterizedQuery query = `SELECT o.id, o.name, o.industry, o.size 
                                    FROM organizations o
                                    JOIN recruiters r ON o.id = r.organization_id
                                    WHERE r.user_id = ${userId}::uuid`;
    return dbClient->queryRow(query);
}

# Checks if a user belongs to an organization.
#
# + dbClient - Database client
# + userId - User ID
# + organizationId - Organization ID
# + return - True if belongs, false otherwise (or error)
public function checkUserInOrganization(postgresql:Client dbClient, string userId, string organizationId) returns boolean|error {
    sql:ParameterizedQuery checkQuery = `SELECT 1 FROM recruiters 
                                          WHERE user_id = ${userId}::uuid AND organization_id = ${organizationId}::uuid`;
    int|sql:Error|sql:NoRowsError checkResult = dbClient->queryRow(checkQuery);

    if checkResult is sql:NoRowsError {
        return false;
    }
    if checkResult is error {
        return checkResult;
    }
    return true;
}

# Updates an organization's details.
#
# + dbClient - Database client
# + organizationId - Organization ID
# + industry - New industry
# + size - New size
# + return - Error if failed
public function updateOrganization(postgresql:Client dbClient, string organizationId, string industry, string size) returns error? {
    sql:ParameterizedQuery updateQuery = `UPDATE organizations 
                                           SET industry = ${industry}, size = ${size}
                                           WHERE id = ${organizationId}::uuid`;
    _ = check dbClient->execute(updateQuery);
    return;
}

# Gets recruiter ID by User ID.
#
# + dbClient - Database client
# + userId - User ID
# + return - Recruiter ID or NoRowsError/Error
public function getRecruiterId(postgresql:Client dbClient, string userId) returns string|sql:NoRowsError|sql:Error {
    sql:ParameterizedQuery query = `SELECT id FROM recruiters WHERE user_id = ${userId}::uuid`;
    return dbClient->queryRow(query);
}

# Creates an interview invitation.
#
# + dbClient - Database client
# + token - Unique token
# + candidateEmail - Candidate email
# + candidateName - Candidate name
# + jobTitle - Job title
# + recruiterId - Recruiter ID (UUID)
# + organizationId - Organization ID (UUID)
# + interviewDate - Interview date (or null)
# + expiresAt - Expiration timestamp
# + return - Invitation ID or error
public function createInvitation(postgresql:Client dbClient, string token, string candidateEmail, string candidateName, string jobTitle, string recruiterId, string organizationId, string? interviewDate, string expiresAt) returns string|error {
    sql:ParameterizedQuery insertQuery = `
        INSERT INTO interview_invitations 
        (token, candidate_email, candidate_name, recruiter_id, organization_id, job_title, interview_date, expires_at, status) 
        VALUES (
            ${token}, 
            ${candidateEmail}, 
            ${candidateName}, 
            ${recruiterId}::uuid, 
            ${organizationId}::uuid, 
            ${jobTitle}, 
            ${interviewDate}::timestamp with time zone, 
            ${expiresAt}::timestamp with time zone, 
            'pending'
        ) 
        RETURNING id`;
    return dbClient->queryRow(insertQuery);
}

# Retrieves invitation by token.
#
# + id - Invitation ID
# + candidate_email - Candidate's email
# + candidate_name - Candidate's name
# + job_title - Job title
# + organization_id - Organization ID
# + expires_at - Expiration timestamp
# + used_at - Used timestamp (optional)
# + status - Invitation status
public type InvitationRecord record {
    string id;
    string candidate_email;
    string? candidate_name;
    string? job_title;
    string organization_id;
    string expires_at;
    string? used_at;
    string status;
};

# Gets invitation details by token.
#
# + dbClient - Database client
# + token - Invitation token
# + return - Invitation details or error
public function getInvitationByToken(postgresql:Client dbClient, string token) returns InvitationRecord|sql:NoRowsError|sql:Error {
    sql:ParameterizedQuery query = `
        SELECT 
            id, candidate_email, candidate_name, job_title, organization_id, 
            expires_at, used_at, status 
        FROM interview_invitations 
        WHERE token = ${token}`;
    return dbClient->queryRow(query);
}

# Marks invitation as expired.
#
# + dbClient - Database client
# + id - Invitation ID
# + return - Error if failed
public function expireInvitation(postgresql:Client dbClient, string id) returns error? {
    sql:ParameterizedQuery updateQuery = `UPDATE interview_invitations SET status = 'expired' WHERE id = ${id}::uuid`;
    _ = check dbClient->execute(updateQuery);
    return;
}

# Marks invitation as accepted/used.
#
# + dbClient - Database client
# + id - Invitation ID
# + usedAt - Used At timestamp string
# + return - Error if failed
public function acceptInvitation(postgresql:Client dbClient, string id, string usedAt) returns error? {
    sql:ParameterizedQuery updateQuery = `
        UPDATE interview_invitations 
        SET used_at = ${usedAt}::timestamp with time zone, status = 'accepted' 
        WHERE id = ${id}::uuid`;
    _ = check dbClient->execute(updateQuery);
    return;
}
