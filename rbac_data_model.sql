-- =====================================================
-- SCALABLE RBAC DATA MODEL FOR SSO INTEGRATION
-- =====================================================

-- Users table (integrates with SSO)
CREATE TABLE users (
    user_id BIGINT PRIMARY KEY AUTO_INCREMENT,
    sso_user_id VARCHAR(255) UNIQUE NOT NULL,  -- External SSO identifier
    email VARCHAR(255) UNIQUE NOT NULL,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_sso_user_id (sso_user_id),
    INDEX idx_email (email),
    INDEX idx_active (is_active)
);

-- Organizations/Tenants (for multi-tenancy support)
CREATE TABLE organizations (
    org_id BIGINT PRIMARY KEY AUTO_INCREMENT,
    org_code VARCHAR(50) UNIQUE NOT NULL,
    org_name VARCHAR(200) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_org_code (org_code)
);

-- Applications/Systems
CREATE TABLE applications (
    app_id BIGINT PRIMARY KEY AUTO_INCREMENT,
    app_code VARCHAR(50) UNIQUE NOT NULL,
    app_name VARCHAR(200) NOT NULL,
    app_description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_app_code (app_code)
);

-- Modules within applications
CREATE TABLE modules (
    module_id BIGINT PRIMARY KEY AUTO_INCREMENT,
    app_id BIGINT NOT NULL,
    module_code VARCHAR(50) NOT NULL,
    module_name VARCHAR(200) NOT NULL,
    module_description TEXT,
    parent_module_id BIGINT NULL,  -- For hierarchical modules
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (app_id) REFERENCES applications(app_id) ON DELETE CASCADE,
    FOREIGN KEY (parent_module_id) REFERENCES modules(module_id) ON DELETE SET NULL,
    UNIQUE KEY uk_module_app (app_id, module_code),
    INDEX idx_parent_module (parent_module_id)
);

-- Resources (pages, APIs, services, etc.)
CREATE TABLE resources (
    resource_id BIGINT PRIMARY KEY AUTO_INCREMENT,
    module_id BIGINT NOT NULL,
    resource_code VARCHAR(100) NOT NULL,
    resource_name VARCHAR(200) NOT NULL,
    resource_type ENUM('PAGE', 'API', 'SERVICE', 'MENU', 'BUTTON', 'DATA') NOT NULL,
    resource_path VARCHAR(500),  -- URL path or API endpoint
    resource_description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (module_id) REFERENCES modules(module_id) ON DELETE CASCADE,
    UNIQUE KEY uk_resource_module (module_id, resource_code),
    INDEX idx_resource_type (resource_type),
    INDEX idx_resource_path (resource_path)
);

-- Permissions/Actions
CREATE TABLE permissions (
    permission_id BIGINT PRIMARY KEY AUTO_INCREMENT,
    permission_code VARCHAR(100) UNIQUE NOT NULL,
    permission_name VARCHAR(200) NOT NULL,
    permission_description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_permission_code (permission_code)
);

-- Resource-Permission mapping (what can be done on each resource)
CREATE TABLE resource_permissions (
    resource_permission_id BIGINT PRIMARY KEY AUTO_INCREMENT,
    resource_id BIGINT NOT NULL,
    permission_id BIGINT NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (resource_id) REFERENCES resources(resource_id) ON DELETE CASCADE,
    FOREIGN KEY (permission_id) REFERENCES permissions(permission_id) ON DELETE CASCADE,
    UNIQUE KEY uk_resource_permission (resource_id, permission_id),
    INDEX idx_resource_id (resource_id),
    INDEX idx_permission_id (permission_id)
);

-- Roles
CREATE TABLE roles (
    role_id BIGINT PRIMARY KEY AUTO_INCREMENT,
    org_id BIGINT NOT NULL,
    role_code VARCHAR(100) NOT NULL,
    role_name VARCHAR(200) NOT NULL,
    role_description TEXT,
    role_level INT DEFAULT 0,  -- For hierarchy (0=lowest, higher=more senior)
    parent_role_id BIGINT NULL,  -- For role inheritance
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (org_id) REFERENCES organizations(org_id) ON DELETE CASCADE,
    FOREIGN KEY (parent_role_id) REFERENCES roles(role_id) ON DELETE SET NULL,
    UNIQUE KEY uk_role_org (org_id, role_code),
    INDEX idx_role_level (role_level),
    INDEX idx_parent_role (parent_role_id)
);

-- Role-Resource-Permission assignments (core RBAC)
CREATE TABLE role_permissions (
    role_permission_id BIGINT PRIMARY KEY AUTO_INCREMENT,
    role_id BIGINT NOT NULL,
    resource_id BIGINT NOT NULL,
    permission_id BIGINT NOT NULL,
    access_type ENUM('ALLOW', 'DENY') DEFAULT 'ALLOW',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by BIGINT,
    
    FOREIGN KEY (role_id) REFERENCES roles(role_id) ON DELETE CASCADE,
    FOREIGN KEY (resource_id) REFERENCES resources(resource_id) ON DELETE CASCADE,
    FOREIGN KEY (permission_id) REFERENCES permissions(permission_id) ON DELETE CASCADE,
    FOREIGN KEY (created_by) REFERENCES users(user_id) ON DELETE SET NULL,
    UNIQUE KEY uk_role_resource_permission (role_id, resource_id, permission_id),
    INDEX idx_role_id (role_id),
    INDEX idx_resource_permission (resource_id, permission_id)
);

-- User-Role assignments (supports multiple roles per user)
CREATE TABLE user_roles (
    user_role_id BIGINT PRIMARY KEY AUTO_INCREMENT,
    user_id BIGINT NOT NULL,
    role_id BIGINT NOT NULL,
    org_id BIGINT NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    effective_from TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    effective_to TIMESTAMP NULL,
    assigned_by BIGINT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (role_id) REFERENCES roles(role_id) ON DELETE CASCADE,
    FOREIGN KEY (org_id) REFERENCES organizations(org_id) ON DELETE CASCADE,
    FOREIGN KEY (assigned_by) REFERENCES users(user_id) ON DELETE SET NULL,
    UNIQUE KEY uk_user_role_org (user_id, role_id, org_id),
    INDEX idx_user_id (user_id),
    INDEX idx_role_id (role_id),
    INDEX idx_effective_dates (effective_from, effective_to)
);

-- User groups (for easier management)
CREATE TABLE user_groups (
    group_id BIGINT PRIMARY KEY AUTO_INCREMENT,
    org_id BIGINT NOT NULL,
    group_code VARCHAR(100) NOT NULL,
    group_name VARCHAR(200) NOT NULL,
    group_description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (org_id) REFERENCES organizations(org_id) ON DELETE CASCADE,
    UNIQUE KEY uk_group_org (org_id, group_code)
);

-- User-Group memberships
CREATE TABLE user_group_members (
    user_group_member_id BIGINT PRIMARY KEY AUTO_INCREMENT,
    user_id BIGINT NOT NULL,
    group_id BIGINT NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (group_id) REFERENCES user_groups(group_id) ON DELETE CASCADE,
    UNIQUE KEY uk_user_group (user_id, group_id)
);

-- Group-Role assignments
CREATE TABLE group_roles (
    group_role_id BIGINT PRIMARY KEY AUTO_INCREMENT,
    group_id BIGINT NOT NULL,
    role_id BIGINT NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (group_id) REFERENCES user_groups(group_id) ON DELETE CASCADE,
    FOREIGN KEY (role_id) REFERENCES roles(role_id) ON DELETE CASCADE,
    UNIQUE KEY uk_group_role (group_id, role_id)
);

-- Audit trail for permission changes
CREATE TABLE audit_logs (
    audit_id BIGINT PRIMARY KEY AUTO_INCREMENT,
    table_name VARCHAR(100) NOT NULL,
    record_id BIGINT NOT NULL,
    action ENUM('INSERT', 'UPDATE', 'DELETE') NOT NULL,
    old_values JSON,
    new_values JSON,
    changed_by BIGINT,
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ip_address VARCHAR(45),
    user_agent TEXT,
    
    FOREIGN KEY (changed_by) REFERENCES users(user_id) ON DELETE SET NULL,
    INDEX idx_table_record (table_name, record_id),
    INDEX idx_changed_at (changed_at),
    INDEX idx_changed_by (changed_by)
);

-- Session management for SSO integration
CREATE TABLE user_sessions (
    session_id BIGINT PRIMARY KEY AUTO_INCREMENT,
    user_id BIGINT NOT NULL,
    sso_session_id VARCHAR(255),
    session_token VARCHAR(500),
    ip_address VARCHAR(45),
    user_agent TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    expires_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_accessed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    INDEX idx_user_session (user_id, is_active),
    INDEX idx_sso_session (sso_session_id),
    INDEX idx_expires_at (expires_at)
);

-- =====================================================
-- SAMPLE DATA INSERTION
-- =====================================================

-- Insert sample organization
INSERT INTO organizations (org_code, org_name) VALUES ('MAIN_ORG', 'Main Organization');

-- Insert sample applications
INSERT INTO applications (app_code, app_name, app_description) VALUES 
('PAYROLL_APP', 'Payroll Management System', 'System for managing payroll operations'),
('HR_APP', 'Human Resources System', 'System for HR operations');

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
UPDATE roles SET parent_role_id = (SELECT role_id FROM (SELECT role_id FROM roles WHERE role_code = 'SPECIALIST') AS r1) WHERE role_code = 'LEAD';
UPDATE roles SET parent_role_id = (SELECT role_id FROM (SELECT role_id FROM roles WHERE role_code = 'LEAD') AS r1) WHERE role_code = 'MANAGER';

-- =====================================================
-- USEFUL VIEWS FOR EASIER QUERYING
-- =====================================================

-- View to get effective permissions for users
CREATE VIEW user_effective_permissions AS
SELECT DISTINCT
    u.user_id,
    u.sso_user_id,
    u.email,
    ur.org_id,
    r.role_code,
    r.role_name,
    res.resource_code,
    res.resource_name,
    res.resource_type,
    res.resource_path,
    p.permission_code,
    p.permission_name,
    rp.access_type
FROM users u
JOIN user_roles ur ON u.user_id = ur.user_id AND ur.is_active = TRUE
JOIN roles r ON ur.role_id = r.role_id AND r.is_active = TRUE
JOIN role_permissions rp ON r.role_id = rp.role_id AND rp.is_active = TRUE
JOIN resources res ON rp.resource_id = res.resource_id AND res.is_active = TRUE
JOIN permissions p ON rp.permission_id = p.permission_id AND p.is_active = TRUE
WHERE u.is_active = TRUE
AND (ur.effective_to IS NULL OR ur.effective_to > NOW());

-- View for role hierarchy
CREATE VIEW role_hierarchy AS
WITH RECURSIVE role_tree AS (
    SELECT role_id, role_code, role_name, parent_role_id, role_level, 0 as depth,
           CAST(role_code AS CHAR(1000)) as path
    FROM roles 
    WHERE parent_role_id IS NULL
    
    UNION ALL
    
    SELECT r.role_id, r.role_code, r.role_name, r.parent_role_id, r.role_level, rt.depth + 1,
           CONCAT(rt.path, ' -> ', r.role_code)
    FROM roles r
    JOIN role_tree rt ON r.parent_role_id = rt.role_id
)
SELECT * FROM role_tree;

-- =====================================================
-- INDEXES FOR PERFORMANCE
-- =====================================================

-- Additional performance indexes
CREATE INDEX idx_user_roles_active ON user_roles(user_id, is_active, effective_from, effective_to);
CREATE INDEX idx_role_permissions_active ON role_permissions(role_id, is_active);
CREATE INDEX idx_resources_active ON resources(module_id, is_active, resource_type);
CREATE INDEX idx_audit_logs_date ON audit_logs(table_name, changed_at);

-- =====================================================
-- SAMPLE QUERIES FOR COMMON OPERATIONS
-- =====================================================

/*
-- Check if user has permission for a specific resource
SELECT COUNT(*) > 0 as has_permission
FROM user_effective_permissions 
WHERE sso_user_id = 'user123@company.com'
AND resource_code = 'PAYROLL_MAKER'
AND permission_code = 'READ'
AND access_type = 'ALLOW';

-- Get all resources a user can access
SELECT DISTINCT resource_code, resource_name, resource_path, permission_code
FROM user_effective_permissions 
WHERE sso_user_id = 'user123@company.com'
AND access_type = 'ALLOW'
ORDER BY resource_name, permission_code;

-- Get all users with a specific role
SELECT u.sso_user_id, u.email, u.first_name, u.last_name
FROM users u
JOIN user_roles ur ON u.user_id = ur.user_id
JOIN roles r ON ur.role_id = r.role_id
WHERE r.role_code = 'MANAGER'
AND ur.is_active = TRUE
AND u.is_active = TRUE;
*/