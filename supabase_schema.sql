-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Organizations Table
CREATE TABLE public.organizations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    industry VARCHAR(100),
    size VARCHAR(50),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Users Table (Linking Supabase Auth with our Organizations)
CREATE TABLE public.recruiters (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL, -- Reference to Supabase Auth User ID (or Asgardeo Subject ID)
    email VARCHAR(255) NOT NULL UNIQUE,
    full_name VARCHAR(255),
    organization_id UUID REFERENCES public.organizations(id) ON DELETE SET NULL,
    role VARCHAR(50) DEFAULT 'recruiter', -- 'admin', 'hiring_manager', 'recruiter'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Row Level Security (RLS)
ALTER TABLE public.organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.recruiters ENABLE ROW LEVEL SECURITY;

-- Policy: Recruiters can view their own organization
CREATE POLICY "Recruiters can view own org" ON public.organizations
    FOR SELECT USING (
        id IN (SELECT organization_id FROM public.recruiters WHERE user_id = auth.uid())
    );

-- Policy: Recruiters can view their own profile and others in their org
CREATE POLICY "Recruiters can view org profiles" ON public.recruiters
    FOR SELECT USING (
        user_id = auth.uid() OR organization_id IN (SELECT organization_id FROM public.recruiters WHERE user_id = auth.uid())
    );

-- Evaluation Templates Table
CREATE TABLE public.evaluation_templates (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    type VARCHAR(50) DEFAULT 'QUESTIONNAIRE', -- 'CV_SCREENING', 'QUESTIONNAIRE', etc.
    prompt_template TEXT NOT NULL,
    is_system_template BOOLEAN DEFAULT false,
    organization_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- RLS for Evaluation Templates
ALTER TABLE public.evaluation_templates ENABLE ROW LEVEL SECURITY;

-- Policy: Everyone (or authenticated) can view system templates
CREATE POLICY "Anyone can view system templates" ON public.evaluation_templates
    FOR SELECT USING (is_system_template = true);

-- Policy: Recruiters can view their org's templates
CREATE POLICY "Recruiters can view org templates" ON public.evaluation_templates
    FOR SELECT USING (
        organization_id IN (SELECT organization_id FROM public.recruiters WHERE user_id = auth.uid())
    );

-- Policy: Recruiters can create templates for their org
CREATE POLICY "Recruiters can create templates" ON public.evaluation_templates
    FOR INSERT WITH CHECK (
        organization_id IN (SELECT organization_id FROM public.recruiters WHERE user_id = auth.uid())
        AND is_system_template = false -- Recruiters cannot create system templates
    );

-- Policy: Recruiters can update their org's templates
CREATE POLICY "Recruiters can update org templates" ON public.evaluation_templates
    FOR UPDATE USING (
        organization_id IN (SELECT organization_id FROM public.recruiters WHERE user_id = auth.uid())
        AND is_system_template = false
    );

-- Policy: Recruiters can delete their org's templates
CREATE POLICY "Recruiters can delete org templates" ON public.evaluation_templates
    FOR DELETE USING (
        organization_id IN (SELECT organization_id FROM public.recruiters WHERE user_id = auth.uid())
        AND is_system_template = false
    );


-- Jobs Table (For Hiring Funnel)
CREATE TABLE public.jobs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title VARCHAR(255) NOT NULL,
    description TEXT,
    organization_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    recruiter_id UUID REFERENCES public.recruiters(id) ON DELETE SET NULL,
    evaluation_template_id UUID REFERENCES public.evaluation_templates(id) ON DELETE SET NULL,
    -- Filter Logic
    required_skills JSONB, -- ["Python", "Django", "RestAPI"]
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- RLS for Jobs
ALTER TABLE public.jobs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Recruiters can view own jobs" ON public.jobs
    FOR SELECT USING (
        organization_id IN (SELECT organization_id FROM public.recruiters WHERE user_id = auth.uid())
    );

CREATE POLICY "Recruiters can create jobs" ON public.jobs
    FOR INSERT WITH CHECK (
        organization_id IN (SELECT organization_id FROM public.recruiters WHERE user_id = auth.uid())
    );

-- Interview Invitations Table for Magic Link Authentication
CREATE TABLE IF NOT EXISTS public.interview_invitations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    token VARCHAR(255) UNIQUE NOT NULL,
    candidate_email VARCHAR(255) NOT NULL,
    candidate_name VARCHAR(255),
    recruiter_id UUID REFERENCES public.recruiters(id) ON DELETE SET NULL,
    organization_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    job_id UUID REFERENCES public.jobs(id) ON DELETE CASCADE,
    job_title VARCHAR(255),
    interview_date TIMESTAMP WITH TIME ZONE,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    used_at TIMESTAMP WITH TIME ZONE,
    status VARCHAR(50) DEFAULT 'pending', -- 'pending', 'accepted', 'expired'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Row Level Security (RLS)
ALTER TABLE public.interview_invitations ENABLE ROW LEVEL SECURITY;

-- Policy: Recruiters can view invitations from their organization
CREATE POLICY "Recruiters can view invitations from their org" 
ON public.interview_invitations
FOR SELECT USING (
    organization_id IN (
        SELECT organization_id FROM public.recruiters WHERE user_id = auth.uid()
    )
);

-- Policy: Recruiters can create invitations for their organization
CREATE POLICY "Recruiters can create invitations for their org" 
ON public.interview_invitations
FOR INSERT WITH CHECK (
    organization_id IN (
        SELECT organization_id FROM public.recruiters WHERE user_id = auth.uid()
    )
);

-- Policy: Recruiters can update invitations from their organization
CREATE POLICY "Recruiters can update invitations from their org" 
ON public.interview_invitations
FOR UPDATE USING (
    organization_id IN (
        SELECT organization_id FROM public.recruiters WHERE user_id = auth.uid()
    )
);

-- Policy: Allow public read for token validation (magic link access)
CREATE POLICY "Public can validate tokens" 
ON public.interview_invitations
FOR SELECT USING (true);


-- Anonymous Profiles (Extracted Skills)
CREATE TABLE public.anonymous_profiles (
    candidate_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    invitation_id UUID REFERENCES public.interview_invitations(id) ON DELETE CASCADE,
    job_id UUID REFERENCES public.jobs(id) ON DELETE CASCADE,
    skills JSONB,
    status VARCHAR(50) DEFAULT 'applied', -- 'applied', 'categorized', 'screening', 'shortlisted', 'rejected', 'accepted'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- RLS Policies
ALTER TABLE public.anonymous_profiles ENABLE ROW LEVEL SECURITY;

-- For MVP, we'll allow Authenticated/Anon read/insert/update access to anonymous_profiles
CREATE POLICY "Public read anonymous profiles" 
ON public.anonymous_profiles
FOR SELECT USING (true);

CREATE POLICY "Public insert anonymous profiles" 
ON public.anonymous_profiles
FOR INSERT WITH CHECK (true);

CREATE POLICY "Public update anonymous profiles" 
ON public.anonymous_profiles
FOR UPDATE USING (true);


-- Secure Identities (Vault for R2 Keys)
CREATE TABLE public.secure_identities (
    candidate_id UUID PRIMARY KEY REFERENCES public.anonymous_profiles(candidate_id) ON DELETE CASCADE,
    r2_object_key VARCHAR(1024) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE public.secure_identities ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public insert secure identities" 
ON public.secure_identities
FOR INSERT WITH CHECK (true);

CREATE POLICY "Recruiters can read secure identities" 
ON public.secure_identities
FOR SELECT USING (true); -- In prod, limit to org recruiters


-- Create Questions Table
CREATE TABLE public.questions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    job_id UUID REFERENCES public.jobs(id) ON DELETE CASCADE,
    question_text TEXT NOT NULL,
    sample_answer TEXT,
    keywords JSONB, -- Stored as an array of strings ["keyword1", "keyword2"]
    type VARCHAR(50) DEFAULT 'paragraph', -- 'paragraph', 'code'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- RLS for Questions
ALTER TABLE public.questions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Recruiters can view questions for their jobs" ON public.questions
    FOR SELECT USING (
        job_id IN (
            SELECT id FROM public.jobs 
            WHERE organization_id IN (
                SELECT organization_id FROM public.recruiters WHERE user_id = auth.uid()
            )
        )
    );

CREATE POLICY "Recruiters can insert questions for their jobs" ON public.questions
    FOR INSERT WITH CHECK (
        job_id IN (
            SELECT id FROM public.jobs 
            WHERE organization_id IN (
                SELECT organization_id FROM public.recruiters WHERE user_id = auth.uid()
            )
        )
    );

CREATE POLICY "Recruiters can delete questions for their jobs" ON public.questions
    FOR DELETE USING (
        job_id IN (
            SELECT id FROM public.jobs 
            WHERE organization_id IN (
                SELECT organization_id FROM public.recruiters WHERE user_id = auth.uid()
            )
        )
    );

CREATE POLICY "Recruiters can update questions for their jobs" ON public.questions
    FOR UPDATE USING (
        job_id IN (
            SELECT id FROM public.jobs 
            WHERE organization_id IN (
                SELECT organization_id FROM public.recruiters WHERE user_id = auth.uid()
            )
        )
    );


-- Candidate Answers Table (for Interview Metrics)
CREATE TABLE public.candidate_answers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    candidate_id UUID REFERENCES public.anonymous_profiles(candidate_id) ON DELETE CASCADE,
    question_id UUID REFERENCES public.questions(id) ON DELETE CASCADE,
    answer_text TEXT,
    correctness_score FLOAT CHECK (correctness_score >= 0 AND correctness_score <= 100),
    difficulty_perceived VARCHAR(50), -- 'easy', 'medium', 'hard'
    ai_feedback TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- RLS for Candidate Answers
ALTER TABLE public.candidate_answers ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Recruiters can view candidate answers for their jobs" ON public.candidate_answers
    FOR SELECT USING (
        question_id IN (
            SELECT id FROM public.questions 
            WHERE job_id IN (
                SELECT id FROM public.jobs 
                WHERE organization_id IN (
                    SELECT organization_id FROM public.recruiters WHERE user_id = auth.uid()
                )
            )
        )
    );

CREATE POLICY "Candidates can insert answers" ON public.candidate_answers
    FOR INSERT WITH CHECK (true); 

CREATE POLICY "Candidates can read answers" ON public.candidate_answers
    FOR SELECT USING (true);


-- Evaluation Results Table (Final Gemini Output)
CREATE TABLE public.evaluation_results (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    candidate_id UUID REFERENCES public.anonymous_profiles(candidate_id) ON DELETE CASCADE,
    job_id UUID REFERENCES public.jobs(id) ON DELETE CASCADE,
    cv_score FLOAT CHECK (cv_score >= 0 AND cv_score <= 100),
    skills_score FLOAT CHECK (skills_score >= 0 AND skills_score <= 100),
    interview_score FLOAT CHECK (interview_score >= 0 AND interview_score <= 100),
    overall_score FLOAT CHECK (overall_score >= 0 AND overall_score <= 100),
    summary_feedback TEXT,
    recommended_status VARCHAR(50),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- RLS for Evaluation Results
ALTER TABLE public.evaluation_results ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Recruiters can view evaluation results" ON public.evaluation_results
    FOR SELECT USING (
        job_id IN (
            SELECT id FROM public.jobs 
            WHERE organization_id IN (
                SELECT organization_id FROM public.recruiters WHERE user_id = auth.uid()
            )
        )
    );

CREATE POLICY "System can insert evaluation results" ON public.evaluation_results
    FOR INSERT WITH CHECK (true);

-- Audit Logs Table
CREATE TABLE public.audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    recruiter_id UUID REFERENCES public.recruiters(id) ON DELETE SET NULL,
    action_type VARCHAR(100) NOT NULL,
    entity_type VARCHAR(100) NOT NULL,
    entity_id UUID,
    details JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- RLS for Audit Logs
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Recruiters can view audit logs for their org" ON public.audit_logs
    FOR SELECT USING (
        organization_id IN (SELECT organization_id FROM public.recruiters WHERE user_id = auth.uid())
    );

CREATE POLICY "System can insert audit logs" ON public.audit_logs
    FOR INSERT WITH CHECK (true);


-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_invitations_token ON public.interview_invitations(token);
CREATE INDEX IF NOT EXISTS idx_invitations_status ON public.interview_invitations(status);
CREATE INDEX IF NOT EXISTS idx_invitations_email ON public.interview_invitations(candidate_email);
CREATE INDEX IF NOT EXISTS idx_invitations_expires ON public.interview_invitations(expires_at);

CREATE INDEX IF NOT EXISTS idx_recruiters_org ON public.recruiters(organization_id);
CREATE INDEX IF NOT EXISTS idx_jobs_org ON public.jobs(organization_id);
CREATE INDEX IF NOT EXISTS idx_jobs_recruiter ON public.jobs(recruiter_id);
CREATE INDEX IF NOT EXISTS idx_invitations_org ON public.interview_invitations(organization_id);
CREATE INDEX IF NOT EXISTS idx_invitations_job ON public.interview_invitations(job_id);

CREATE INDEX IF NOT EXISTS idx_anon_profiles_job ON public.anonymous_profiles(job_id);
CREATE INDEX IF NOT EXISTS idx_anon_profiles_invitation ON public.anonymous_profiles(invitation_id);

CREATE INDEX IF NOT EXISTS idx_questions_job ON public.questions(job_id);
CREATE INDEX IF NOT EXISTS idx_candidate_answers_candidate ON public.candidate_answers(candidate_id);
CREATE INDEX IF NOT EXISTS idx_candidate_answers_question ON public.candidate_answers(question_id);

CREATE INDEX IF NOT EXISTS idx_eval_results_candidate ON public.evaluation_results(candidate_id);
CREATE INDEX IF NOT EXISTS idx_eval_results_job ON public.evaluation_results(job_id);

CREATE INDEX IF NOT EXISTS idx_audit_logs_org ON public.audit_logs(organization_id);


-- Function to auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-update updated_at for organizations
CREATE TRIGGER update_organizations_updated_at
    BEFORE UPDATE ON public.organizations
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Trigger to auto-update updated_at for interview_invitations
CREATE TRIGGER update_interview_invitations_updated_at
    BEFORE UPDATE ON public.interview_invitations
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Trigger to auto-update updated_at for evaluation_templates
CREATE TRIGGER update_evaluation_templates_updated_at
    BEFORE UPDATE ON public.evaluation_templates
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Function to auto-expire old tokens (optional - can be called by a cron job)
CREATE OR REPLACE FUNCTION expire_old_invitations()
RETURNS void AS $$
BEGIN
    UPDATE public.interview_invitations
    SET status = 'expired'
    WHERE expires_at < NOW() AND status = 'pending';
END;
$$ LANGUAGE plpgsql;

-- Insert Pre-built System Templates
INSERT INTO public.evaluation_templates (id, name, description, type, prompt_template, is_system_template)
VALUES 
    (uuid_generate_v4(), 'Standard Software Engineer Evaluation', 'Default rigorous technical grading criteria.', 'QUESTIONNAIRE', 'You are an expert technical interviewer. Evaluate the candidate''s answer based on: 1. Technical Accuracy (40%), 2. Code Quality & Best Practices (30%), 3. Problem Solving & Logic (30%). Provide constructive feedback.', true),
    (uuid_generate_v4(), 'Lenient Junior Developer Evaluation', 'Softer grading focused on potential and basic understanding.', 'QUESTIONNAIRE', 'You are an empathetic senior developer evaluating a junior. Focus on: 1. Core Understanding (50%), 2. Willingness to Learn (30%), 3. Syntax (20%). Point out good attempts even if the final code has minor bugs.', true),
    (uuid_generate_v4(), 'Strict Senior Architecture Evaluation', 'Harsh grading focusing on scalability and design patterns.', 'QUESTIONNAIRE', 'You are a strict Staff Engineer. Evaluate the candidate with extreme rigor on: 1. System Design & Scalability (40%), 2. Security (30%), 3. Edge Cases (30%). Reject answers that brute force the solution without considering big-O constraints.', true);
