-- =====================================================
-- SCALABLE RBAC DATA MODEL FOR SSO INTEGRATION - PostgreSQL
-- =====================================================

-- Enable UUID extension for better distributed IDs
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Custom types for better type safety
CREATE TYPE access_type_enum AS ENUM ('ALLOW', 'DENY');
CREATE TYPE resource_type_enum AS ENUM ('PAGE', 'API', 'SERVICE', 'MENU', 'BUTTON', 'DATA');
CREATE TYPE audit_action_enum AS ENUM ('INSERT', 'UPDATE', 'DELETE');

-- Users table (integrates with SSO)
CREATE TABLE users (
    user_id BIGSERIAL PRIMARY KEY,
    user_uuid UUID DEFAULT uuid_generate_v4() UNIQUE NOT NULL,
    sso_user_id VARCHAR(255) UNIQUE NOT NULL,  -- External SSO identifier
    email VARCHAR(255) UNIQUE NOT NULL,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for users
CREATE INDEX idx_users_sso_user_id ON users(sso_user_id);
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_active ON users(is_active);
CREATE INDEX idx_users_uuid ON users(user_uuid);

-- Organizations/Tenants (for multi-tenancy support)
CREATE TABLE organizations (
    org_id BIGSERIAL PRIMARY KEY,
    org_uuid UUID DEFAULT uuid_generate_v4() UNIQUE NOT NULL,
    org_code VARCHAR(50) UNIQUE NOT NULL,
    org_name VARCHAR(200) NOT NULL,
    org_config JSONB DEFAULT '{}',  -- For flexible org-specific configurations
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_organizations_code ON organizations(org_code);
CREATE INDEX idx_organizations_uuid ON organizations(org_uuid);
CREATE INDEX idx_organizations_config ON organizations USING GIN(org_config);

-- Applications/Systems
CREATE TABLE applications (
    app_id BIGSERIAL PRIMARY KEY,
    app_uuid UUID DEFAULT uuid_generate_v4() UNIQUE NOT NULL,
    app_code VARCHAR(50) UNIQUE NOT NULL,
    app_name VARCHAR(200) NOT NULL,
    app_description TEXT,
    app_config JSONB DEFAULT '{}',  -- For app-specific settings
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_applications_code ON applications(app_code);
CREATE INDEX idx_applications_uuid ON applications(app_uuid);
CREATE INDEX idx_applications_config ON applications USING GIN(app_config);

-- Modules within applications
CREATE TABLE modules (
    module_id BIGSERIAL PRIMARY KEY,
    module_uuid UUID DEFAULT uuid_generate_v4() UNIQUE NOT NULL,
    app_id BIGINT NOT NULL REFERENCES applications(app_id) ON DELETE CASCADE,
    module_code VARCHAR(50) NOT NULL,
    module_name VARCHAR(200) NOT NULL,
    module_description TEXT,
    parent_module_id BIGINT REFERENCES modules(module_id) ON DELETE SET NULL,
    module_config JSONB DEFAULT '{}',
    sort_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT uk_module_app UNIQUE(app_id, module_code)
);

CREATE INDEX idx_modules_app_id ON modules(app_id);
CREATE INDEX idx_modules_parent ON modules(parent_module_id);
CREATE INDEX idx_modules_uuid ON modules(module_uuid);
CREATE INDEX idx_modules_config ON modules USING GIN(module_config);

-- Resources (pages, APIs, services, etc.)
CREATE TABLE resources (
    resource_id BIGSERIAL PRIMARY KEY,
    resource_uuid UUID DEFAULT uuid_generate_v4() UNIQUE NOT NULL,
    module_id BIGINT NOT NULL REFERENCES modules(module_id) ON DELETE CASCADE,
    resource_code VARCHAR(100) NOT NULL,
    resource_name VARCHAR(200) NOT NULL,
    resource_type resource_type_enum NOT NULL,
    resource_path VARCHAR(500),  -- URL path or API endpoint
    resource_description TEXT,
    resource_config JSONB DEFAULT '{}',  -- For resource-specific settings
    sort_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT uk_resource_module UNIQUE(module_id, resource_code)
);

CREATE INDEX idx_resources_module_id ON resources(module_id);
CREATE INDEX idx_resources_type ON resources(resource_type);
CREATE INDEX idx_resources_path ON resources(resource_path);
CREATE INDEX idx_resources_uuid ON resources(resource_uuid);
CREATE INDEX idx_resources_config ON resources USING GIN(resource_config);

-- Permissions/Actions
CREATE TABLE permissions (
    permission_id BIGSERIAL PRIMARY KEY,
    permission_uuid UUID DEFAULT uuid_generate_v4() UNIQUE NOT NULL,
    permission_code VARCHAR(100) UNIQUE NOT NULL,
    permission_name VARCHAR(200) NOT NULL,
    permission_description TEXT,
    permission_config JSONB DEFAULT '{}',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_permissions_code ON permissions(permission_code);
CREATE INDEX idx_permissions_uuid ON permissions(permission_uuid);
CREATE INDEX idx_permissions_config ON permissions USING GIN(permission_config);

-- Resource-Permission mapping (what can be done on each resource)
CREATE TABLE resource_permissions (
    resource_permission_id BIGSERIAL PRIMARY KEY,
    resource_id BIGINT NOT NULL REFERENCES resources(resource_id) ON DELETE CASCADE,
    permission_id BIGINT NOT NULL REFERENCES permissions(permission_id) ON DELETE CASCADE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT uk_resource_permission UNIQUE(resource_id, permission_id)
);

CREATE INDEX idx_resource_permissions_resource ON resource_permissions(resource_id);
CREATE INDEX idx_resource_permissions_permission ON resource_permissions(permission_id);

-- Roles
CREATE TABLE roles (
    role_id BIGSERIAL PRIMARY KEY,
    role_uuid UUID DEFAULT uuid_generate_v4() UNIQUE NOT NULL,
    org_id BIGINT NOT NULL REFERENCES organizations(org_id) ON DELETE CASCADE,
    role_code VARCHAR(100) NOT NULL,
    role_name VARCHAR(200) NOT NULL,
    role_description TEXT,
    role_level INTEGER DEFAULT 0,  -- For hierarchy (0=lowest, higher=more senior)
    parent_role_id BIGINT REFERENCES roles(role_id) ON DELETE SET NULL,
    role_config JSONB DEFAULT '{}',  -- For role-specific settings
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT uk_role_org UNIQUE(org_id, role_code)
);

CREATE INDEX idx_roles_org_id ON roles(org_id);
CREATE INDEX idx_roles_level ON roles(role_level);
CREATE INDEX idx_roles_parent ON roles(parent_role_id);
CREATE INDEX idx_roles_uuid ON roles(role_uuid);
CREATE INDEX idx_roles_config ON roles USING GIN(role_config);

-- Role-Resource-Permission assignments (core RBAC)
CREATE TABLE role_permissions (
    role_permission_id BIGSERIAL PRIMARY KEY,
    role_id BIGINT NOT NULL REFERENCES roles(role_id) ON DELETE CASCADE,
    resource_id BIGINT NOT NULL REFERENCES resources(resource_id) ON DELETE CASCADE,
    permission_id BIGINT NOT NULL REFERENCES permissions(permission_id) ON DELETE CASCADE,
    access_type access_type_enum DEFAULT 'ALLOW',
    conditions JSONB DEFAULT '{}',  -- For conditional permissions (time, IP, etc.)
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by BIGINT REFERENCES users(user_id) ON DELETE SET NULL,
    
    CONSTRAINT uk_role_resource_permission UNIQUE(role_id, resource_id, permission_id)
);

CREATE INDEX idx_role_permissions_role ON role_permissions(role_id);
CREATE INDEX idx_role_permissions_resource_permission ON role_permissions(resource_id, permission_id);
CREATE INDEX idx_role_permissions_access_type ON role_permissions(access_type);
CREATE INDEX idx_role_permissions_conditions ON role_permissions USING GIN(conditions);

-- User-Role assignments (supports multiple roles per user)
CREATE TABLE user_roles (
    user_role_id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    role_id BIGINT NOT NULL REFERENCES roles(role_id) ON DELETE CASCADE,
    org_id BIGINT NOT NULL REFERENCES organizations(org_id) ON DELETE CASCADE,
    is_active BOOLEAN DEFAULT TRUE,
    effective_from TIMESTAMPTZ DEFAULT NOW(),
    effective_to TIMESTAMPTZ NULL,
    assignment_context JSONB DEFAULT '{}',  -- For context-specific assignments
    assigned_by BIGINT REFERENCES users(user_id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT uk_user_role_org UNIQUE(user_id, role_id, org_id)
);

CREATE INDEX idx_user_roles_user ON user_roles(user_id);
CREATE INDEX idx_user_roles_role ON user_roles(role_id);
CREATE INDEX idx_user_roles_org ON user_roles(org_id);
CREATE INDEX idx_user_roles_effective ON user_roles(effective_from, effective_to);
CREATE INDEX idx_user_roles_active ON user_roles(user_id, is_active, effective_from, effective_to);
CREATE INDEX idx_user_roles_context ON user_roles USING GIN(assignment_context);

-- User groups (for easier management)
CREATE TABLE user_groups (
    group_id BIGSERIAL PRIMARY KEY,
    group_uuid UUID DEFAULT uuid_generate_v4() UNIQUE NOT NULL,
    org_id BIGINT NOT NULL REFERENCES organizations(org_id) ON DELETE CASCADE,
    group_code VARCHAR(100) NOT NULL,
    group_name VARCHAR(200) NOT NULL,
    group_description TEXT,
    group_config JSONB DEFAULT '{}',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT uk_group_org UNIQUE(org_id, group_code)
);

CREATE INDEX idx_user_groups_org ON user_groups(org_id);
CREATE INDEX idx_user_groups_uuid ON user_groups(group_uuid);
CREATE INDEX idx_user_groups_config ON user_groups USING GIN(group_config);

-- User-Group memberships
CREATE TABLE user_group_members (
    user_group_member_id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    group_id BIGINT NOT NULL REFERENCES user_groups(group_id) ON DELETE CASCADE,
    is_active BOOLEAN DEFAULT TRUE,
    joined_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT uk_user_group UNIQUE(user_id, group_id)
);

CREATE INDEX idx_user_group_members_user ON user_group_members(user_id);
CREATE INDEX idx_user_group_members_group ON user_group_members(group_id);

-- Group-Role assignments
CREATE TABLE group_roles (
    group_role_id BIGSERIAL PRIMARY KEY,
    group_id BIGINT NOT NULL REFERENCES user_groups(group_id) ON DELETE CASCADE,
    role_id BIGINT NOT NULL REFERENCES roles(role_id) ON DELETE CASCADE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT uk_group_role UNIQUE(group_id, role_id)
);

CREATE INDEX idx_group_roles_group ON group_roles(group_id);
CREATE INDEX idx_group_roles_role ON group_roles(role_id);

-- Audit trail for permission changes
CREATE TABLE audit_logs (
    audit_id BIGSERIAL PRIMARY KEY,
    audit_uuid UUID DEFAULT uuid_generate_v4() UNIQUE NOT NULL,
    table_name VARCHAR(100) NOT NULL,
    record_id BIGINT NOT NULL,
    record_uuid UUID,
    action audit_action_enum NOT NULL,
    old_values JSONB,
    new_values JSONB,
    changed_by BIGINT REFERENCES users(user_id) ON DELETE SET NULL,
    changed_at TIMESTAMPTZ DEFAULT NOW(),
    ip_address INET,
    user_agent TEXT,
    session_id VARCHAR(255)
);

CREATE INDEX idx_audit_logs_table_record ON audit_logs(table_name, record_id);
CREATE INDEX idx_audit_logs_uuid ON audit_logs(record_uuid);
CREATE INDEX idx_audit_logs_changed_at ON audit_logs(changed_at);
CREATE INDEX idx_audit_logs_changed_by ON audit_logs(changed_by);
CREATE INDEX idx_audit_logs_old_values ON audit_logs USING GIN(old_values);
CREATE INDEX idx_audit_logs_new_values ON audit_logs USING GIN(new_values);

-- Session management for SSO integration
CREATE TABLE user_sessions (
    session_id BIGSERIAL PRIMARY KEY,
    session_uuid UUID DEFAULT uuid_generate_v4() UNIQUE NOT NULL,
    user_id BIGINT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    sso_session_id VARCHAR(255),
    session_token TEXT,
    refresh_token TEXT,
    ip_address INET,
    user_agent TEXT,
    session_data JSONB DEFAULT '{}',
    is_active BOOLEAN DEFAULT TRUE,
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    last_accessed_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_user_sessions_user ON user_sessions(user_id, is_active);
CREATE INDEX idx_user_sessions_sso ON user_sessions(sso_session_id);
CREATE INDEX idx_user_sessions_expires ON user_sessions(expires_at);
CREATE INDEX idx_user_sessions_uuid ON user_sessions(session_uuid);
CREATE INDEX idx_user_sessions_data ON user_sessions USING GIN(session_data);

-- Permission cache for performance (optional)
CREATE TABLE permission_cache (
    cache_id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    org_id BIGINT NOT NULL REFERENCES organizations(org_id) ON DELETE CASCADE,
    resource_code VARCHAR(100) NOT NULL,
    permission_code VARCHAR(100) NOT NULL,
    has_permission BOOLEAN NOT NULL,
    cache_key VARCHAR(500) NOT NULL,
    cached_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '1 hour'),
    
    CONSTRAINT uk_permission_cache UNIQUE(cache_key)
);

CREATE INDEX idx_permission_cache_user_org ON permission_cache(user_id, org_id);
CREATE INDEX idx_permission_cache_expires ON permission_cache(expires_at);

-- =====================================================
-- FUNCTIONS AND TRIGGERS
-- =====================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Add triggers for updated_at
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_organizations_updated_at BEFORE UPDATE ON organizations 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_applications_updated_at BEFORE UPDATE ON applications 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_modules_updated_at BEFORE UPDATE ON modules 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_resources_updated_at BEFORE UPDATE ON resources 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_permissions_updated_at BEFORE UPDATE ON permissions 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_roles_updated_at BEFORE UPDATE ON roles 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_user_groups_updated_at BEFORE UPDATE ON user_groups 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Function to check role hierarchy (prevents circular references)
CREATE OR REPLACE FUNCTION check_role_hierarchy()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.parent_role_id IS NOT NULL THEN
        -- Check if this would create a circular reference
        WITH RECURSIVE role_tree AS (
            SELECT role_id, parent_role_id, 1 as depth
            FROM roles 
            WHERE role_id = NEW.parent_role_id
            
            UNION ALL
            
            SELECT r.role_id, r.parent_role_id, rt.depth + 1
            FROM roles r
            JOIN role_tree rt ON r.role_id = rt.parent_role_id
            WHERE rt.depth < 10  -- Prevent infinite recursion
        )
        SELECT INTO NEW.parent_role_id 
        CASE 
            WHEN EXISTS(SELECT 1 FROM role_tree WHERE role_id = NEW.role_id) 
            THEN NULL 
            ELSE NEW.parent_role_id 
        END;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER check_role_hierarchy_trigger 
    BEFORE INSERT OR UPDATE ON roles 
    FOR EACH ROW EXECUTE FUNCTION check_role_hierarchy();

-- Audit trigger function
CREATE OR REPLACE FUNCTION audit_trigger_function()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        INSERT INTO audit_logs(table_name, record_id, action, old_values)
        VALUES (TG_TABLE_NAME, OLD.id, 'DELETE', row_to_json(OLD));
        RETURN OLD;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO audit_logs(table_name, record_id, action, old_values, new_values)
        VALUES (TG_TABLE_NAME, NEW.id, 'UPDATE', row_to_json(OLD), row_to_json(NEW));
        RETURN NEW;
    ELSIF TG_OP = 'INSERT' THEN
        INSERT INTO audit_logs(table_name, record_id, action, new_values)
        VALUES (TG_TABLE_NAME, NEW.id, 'INSERT', row_to_json(NEW));
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- SAMPLE DATA INSERTION
-- =====================================================

-- Insert sample organization
INSERT INTO organizations (org_code, org_name, org_config) VALUES 
('MAIN_ORG', 'Main Organization', '{"timezone": "UTC", "currency": "USD"}');

-- Insert sample applications
INSERT INTO applications (app_code, app_name, app_description, app_config) VALUES 
('PAYROLL_APP', 'Payroll Management System', 'System for managing payroll operations', '{"version": "2.0", "theme": "default"}'),
('HR_APP', 'Human Resources System', 'System for HR operations', '{"version": "1.5", "theme": "corporate"}');

-- Insert sample permissions
INSERT INTO permissions (permission_code, permission_name, permission_description) VALUES
('READ', 'Read', 'View/Read access to resources'),
('WRITE', 'Write', 'Create/Update access to resources'),
('DELETE', 'Delete', 'Delete access to resources'),
('EXECUTE', 'Execute', 'Execute operations on resources'),
('APPROVE', 'Approve', 'Approval permissions'),
('ADMIN', 'Admin', 'Administrative permissions');

-- Insert sample modules
INSERT INTO modules (app_id, module_code, module_name, module_description) VALUES
(1, 'PAYROLL_PROC', 'Payroll Processing', 'Core payroll processing functionality'),
(1, 'PAYROLL_REPORTS', 'Payroll Reports', 'Payroll reporting and analytics'),
(2, 'EMPLOYEE_MGMT', 'Employee Management', 'Employee data management');

-- Insert sample resources
INSERT INTO resources (module_id, resource_code, resource_name, resource_type, resource_path) VALUES
(1, 'PAYROLL_MAKER', 'Payroll Maker', 'PAGE', '/payroll/maker'),
(1, 'PAYROLL_CHECKER', 'Payroll Checker', 'PAGE', '/payroll/checker'),
(1, 'ERROR_CORRECTION', 'Input Error Correction', 'PAGE', '/payroll/error-correction'),
(1, 'PAST_PROCESSING', 'Past Processing', 'PAGE', '/payroll/past-processing'),
(1, 'HELP_DESK', 'Help Desk', 'PAGE', '/payroll/help'),
(2, 'PAYROLL_DASHBOARD', 'Payroll Dashboard', 'PAGE', '/payroll/dashboard');

-- Insert sample roles based on your hierarchy
INSERT INTO roles (org_id, role_code, role_name, role_description, role_level) VALUES
(1, 'SPECIALIST', 'Specialist', 'Entry level specialist role', 1),
(1, 'LEAD', 'Lead', 'Lead specialist role', 2),
(1, 'MANAGER', 'Manager', 'Manager role', 3);

-- Set up role hierarchy
UPDATE roles SET parent_role_id = (
    SELECT role_id FROM roles WHERE role_code = 'SPECIALIST' AND org_id = 1
) WHERE role_code = 'LEAD' AND org_id = 1;

UPDATE roles SET parent_role_id = (
    SELECT role_id FROM roles WHERE role_code = 'LEAD' AND org_id = 1
) WHERE role_code = 'MANAGER' AND org_id = 1;

-- =====================================================
-- USEFUL VIEWS FOR EASIER QUERYING
-- =====================================================

-- View to get effective permissions for users (with inheritance)
CREATE OR REPLACE VIEW user_effective_permissions AS
WITH RECURSIVE role_inheritance AS (
    -- Direct roles
    SELECT ur.user_id, ur.role_id, r.role_code, r.role_name, r.role_level, ur.org_id
    FROM user_roles ur
    JOIN roles r ON ur.role_id = r.role_id
    WHERE ur.is_active = TRUE 
    AND r.is_active = TRUE
    AND (ur.effective_to IS NULL OR ur.effective_to > NOW())
    
    UNION
    
    -- Inherited roles through groups
    SELECT ugm.user_id, gr.role_id, r.role_code, r.role_name, r.role_level, ug.org_id
    FROM user_group_members ugm
    JOIN user_groups ug ON ugm.group_id = ug.group_id
    JOIN group_roles gr ON ug.group_id = gr.group_id
    JOIN roles r ON gr.role_id = r.role_id
    WHERE ugm.is_active = TRUE 
    AND ug.is_active = TRUE 
    AND gr.is_active = TRUE 
    AND r.is_active = TRUE
    
    UNION
    
    -- Parent role inheritance
    SELECT ri.user_id, pr.role_id, pr.role_code, pr.role_name, pr.role_level, ri.org_id
    FROM role_inheritance ri
    JOIN roles cr ON ri.role_id = cr.role_id
    JOIN roles pr ON cr.parent_role_id = pr.role_id
    WHERE pr.is_active = TRUE
)
SELECT DISTINCT
    u.user_id,
    u.user_uuid,
    u.sso_user_id,
    u.email,
    ri.org_id,
    ri.role_code,
    ri.role_name,
    a.app_code,
    m.module_code,
    res.resource_code,
    res.resource_name,
    res.resource_type,
    res.resource_path,
    p.permission_code,
    p.permission_name,
    rp.access_type,
    rp.conditions
FROM users u
JOIN role_inheritance ri ON u.user_id = ri.user_id
JOIN role_permissions rp ON ri.role_id = rp.role_id AND rp.is_active = TRUE
JOIN resources res ON rp.resource_id = res.resource_id AND res.is_active = TRUE
JOIN modules m ON res.module_id = m.module_id AND m.is_active = TRUE
JOIN applications a ON m.app_id = a.app_id AND a.is_active = TRUE
JOIN permissions p ON rp.permission_id = p.permission_id AND p.is_active = TRUE
WHERE u.is_active = TRUE;

-- View for role hierarchy with full path
CREATE OR REPLACE VIEW role_hierarchy AS
WITH RECURSIVE role_tree AS (
    SELECT 
        role_id, 
        role_uuid,
        org_id,
        role_code, 
        role_name, 
        parent_role_id, 
        role_level, 
        0 as depth,
        role_code as path,
        ARRAY[role_id] as path_ids
    FROM roles 
    WHERE parent_role_id IS NULL AND is_active = TRUE
    
    UNION ALL
    
    SELECT 
        r.role_id, 
        r.role_uuid,
        r.org_id,
        r.role_code, 
        r.role_name, 
        r.parent_role_id, 
        r.role_level, 
        rt.depth + 1,
        rt.path || ' -> ' || r.role_code,
        rt.path_ids || r.role_id
    FROM roles r
    JOIN role_tree rt ON r.parent_role_id = rt.role_id
    WHERE r.is_active = TRUE AND NOT r.role_id = ANY(rt.path_ids)
)
SELECT * FROM role_tree;

-- Materialized view for permission cache (refresh periodically)
CREATE MATERIALIZED VIEW user_permission_cache AS
SELECT 
    u.user_id,
    u.sso_user_id,
    o.org_id,
    o.org_code,
    a.app_code,
    res.resource_code,
    p.permission_code,
    bool_or(CASE WHEN uep.access_type = 'ALLOW' THEN TRUE ELSE FALSE END) as has_permission,
    NOW() as cached_at
FROM users u
CROSS JOIN organizations o
CROSS JOIN applications a
CROSS JOIN resources res
CROSS JOIN permissions p
LEFT JOIN user_effective_permissions uep ON (
    u.user_id = uep.user_id 
    AND o.org_id = uep.org_id 
    AND a.app_code = uep.app_code
    AND res.resource_code = uep.resource_code 
    AND p.permission_code = uep.permission_code
)
WHERE u.is_active = TRUE 
AND o.is_active = TRUE 
AND a.is_active = TRUE 
AND res.is_active = TRUE 
AND p.is_active = TRUE
GROUP BY u.user_id, u.sso_user_id, o.org_id, o.org_code, a.app_code, res.resource_code, p.permission_code;

-- Create unique index on materialized view
CREATE UNIQUE INDEX idx_user_permission_cache_unique 
ON user_permission_cache(user_id, org_id, app_code, resource_code, permission_code);

-- =====================================================
-- UTILITY FUNCTIONS
-- =====================================================

-- Function to check user permission
CREATE OR REPLACE FUNCTION check_user_permission(
    p_sso_user_id VARCHAR,
    p_org_code VARCHAR,
    p_app_code VARCHAR,
    p_resource_code VARCHAR,
    p_permission_code VARCHAR
) RETURNS BOOLEAN AS $$
DECLARE
    has_perm BOOLEAN := FALSE;
BEGIN
    SELECT COALESCE(has_permission, FALSE)
    INTO has_perm
    FROM user_permission_cache upc
    JOIN users u ON upc.user_id = u.user_id
    WHERE u.sso_user_id = p_sso_user_id
    AND upc.org_code = p_org_code
    AND upc.app_code = p_app_code
    AND upc.resource_code = p_resource_code
    AND upc.permission_code = p_permission_code;
    
    RETURN COALESCE(has_perm, FALSE);
END;
$$ LANGUAGE plpgsql;

-- Function to get user menu items based on permissions
CREATE OR REPLACE FUNCTION get_user_menu_items(
    p_sso_user_id VARCHAR,
    p_org_code VARCHAR,
    p_app_code VARCHAR
) RETURNS TABLE (
    resource_code VARCHAR,
    resource_name VARCHAR,
    resource_path VARCHAR,
    module_name VARCHAR,
    sort_order INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT
        r.resource_code,
        r.resource_name,
        r.resource_path,
        m.module_name,
        r.sort_order
    FROM user_effective_permissions uep
    JOIN resources r ON uep.resource_code = r.resource_code
    JOIN modules m ON r.module_id = m.module_id
    JOIN organizations o ON uep.org_id = o.org_id
    WHERE uep.sso_user_id = p_sso_user_id
    AND o.org_code = p_org_code
    AND uep.app_code = p_app_code
    AND r.resource_type IN ('PAGE', 'MENU')
    AND uep.permission_code = 'READ'
    AND uep.access_type = 'ALLOW'
    ORDER BY r.sort_order, r.resource_name;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- SAMPLE QUERIES FOR COMMON OPERATIONS
-- =====================================================

/*
-- Check if user has permission for a specific resource
SELECT check_user_permission(
    'user123@company.com',
    'MAIN_ORG', 
    'PAYROLL_APP',
    'PAYROLL_MAKER',
    'READ'
) as has_permission;

-- Get all menu items a user can access
SELECT * FROM get_user_menu_items(
    'user123@company.com',
    'MAIN_ORG',
    'PAYROLL_APP'
);

-- Get all resources a user can access with permissions
SELECT DISTINCT 
    app_code,
    module_code,
    resource_code, 
    resource_name, 
    resource_path, 
    permission_code,
    access_type
FROM user_effective_permissions 
WHERE sso_user_id = 'user123@company.com'
AND org_id = 1
AND access_type = 'ALLOW'
ORDER BY app_code, module_code, resource_name, permission_code;

-- Get all users with a specific role
SELECT