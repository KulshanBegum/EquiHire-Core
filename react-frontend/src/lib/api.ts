

const API_BASE_url = "http://localhost:9092/api";

export const API = {
    getOrganization: async (userId: string) => {
        const response = await fetch(`${API_BASE_url}/me/organization?userId=${userId}`);
        if (!response.ok) {
            if (response.status === 404) return null;
            throw new Error("Failed to fetch organization");
        }
        return response.json();
    },

    createOrganization: async (data: { name: string; industry: string; size: string; userEmail: string; userId: string }) => {
        const response = await fetch(`${API_BASE_url}/organizations`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data),
        });
        if (!response.ok) {
            throw new Error("Failed to create organization");
        }
        return response;
    },

    updateOrganization: async (orgId: string, data: { industry: string; size: string; }, userId: string) => {
        const response = await fetch(`${API_BASE_url}/organization?userId=${userId}`, {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ ...data, id: orgId }),
        });
        if (!response.ok) throw new Error("Failed to update organization");
        return response;
    },

    createInvitation: async (data: any) => {
        const response = await fetch(`${API_BASE_url}/invitations`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data),
        });
        if (!response.ok) throw new Error("Failed to send invitation");
        return response.json();
    },

    validateInvitation: async (token: string) => {
        const response = await fetch(`${API_BASE_url}/invitations/validate/${token}`);
        if (!response.ok) throw new Error("Invalid or expired token");
        return response.json();
    }
};
