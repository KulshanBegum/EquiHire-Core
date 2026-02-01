
# Represents a request to register a new organization and admin.
#
# + name - Name of the organization
# + industry - Industry sector
# + size - Organization size (e.g., "1-10", "11-50")
# + userEmail - Email of the admin user
# + userId - User ID from the identity provider
public type OrganizationRequest record {
    string name;
    string industry;
    string size;
    string userEmail;
    string userId;
};

# Represents an organization response.
#
# + id - Organization ID
# + name - Organization name
# + industry - Industry sector
# + size - Organization size
public type OrganizationResponse record {
    string id;
    string name;
    string industry;
    string size;
};

# Represents an invitation request.
#
# + candidateEmail - Email of the candidate
# + candidateName - Name of the candidate
# + jobTitle - Job title for the interview
# + interviewDate - Optional interview date (ISO 8601)
# + organizationId - Organization ID
# + recruiterId - Recruiter's User ID
public type InvitationRequest record {
    string candidateEmail;
    string candidateName;
    string jobTitle;
    string? interviewDate;
    string organizationId;
    string recruiterId;
};

# Represents an invitation response.
#
# + id - Invitation ID
# + token - Unique token for the link
# + magicLink - Full magic link URL
# + candidateEmail - Candidate's email
# + expiresAt - Expiration timestamp
public type InvitationResponse record {
    string id;
    string token;
    string magicLink;
    string candidateEmail;
    string expiresAt;
};

# Represents the token validation result.
#
# + valid - Whether the token is valid
# + candidateEmail - Candidate's email (if valid)
# + candidateName - Candidate's name (if valid)
# + jobTitle - Job title (if valid)
# + organizationId - Organization ID (if valid)
# + message - Error message (if invalid)
public type TokenValidationResponse record {
    boolean valid;
    string? candidateEmail?;
    string? candidateName?;
    string? jobTitle?;
    string? organizationId?;
    string? message?;
};

# Database connection configuration.
#
# + host - Database host
# + port - Database port
# + user - Database user
# + password - Database password
# + name - Database name
public type DatabaseConfig record {
    string host;
    int port;
    string user;
    string password;
    string name;
};
