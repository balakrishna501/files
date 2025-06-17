-- =====================================================
-- APPLICATION-SPECIFIC ROLE-BASED ACCESS CONTROL MODEL
-- (External User Management - No User Storage)
-- =====================================================

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

-- APPLICATION-SPECIFIC ROLES
CREATE TABLE roles (
    role_id BIGINT PRIMARY KEY AUTO_INCREMENT,
    app_id BIGINT NOT NULL,
    role_code VARCHAR(100) NOT NULL,
    role_name VARCHAR(200) NOT NULL,
    role_description TEXT,
    role_level INT DEFAULT 0,  -- For hierarchy within the application
    parent_role_id BIGINT NULL,  -- For role inheritance within same app
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (app_id) REFERENCES applications(app_id) ON DELETE CASCADE,
    FOREIGN KEY (parent_role_id) REFERENCES roles(role_id) ON DELETE SET NULL,
    UNIQUE KEY uk_role_app (app_id, role_code),  -- Role code unique within app
    INDEX idx_role_level (role_level),
    INDEX idx_parent_role (parent_role_id),
    INDEX idx_app_id (app_id)
);

-- Role-Resource-Permission assignments (what roles can do within their application)
CREATE TABLE role_permissions (
    role_permission_id BIGINT PRIMARY KEY AUTO_INCREMENT,
    role_id BIGINT NOT NULL,
    resource_id BIGINT NOT NULL,
    permission_id BIGINT NOT NULL,
    access_type ENUM('ALLOW', 'DENY') DEFAULT 'ALLOW',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (role_id) REFERENCES roles(role_id) ON DELETE CASCADE,
    FOREIGN KEY (resource_id) REFERENCES resources(resource_id) ON DELETE CASCADE,
    FOREIGN KEY (permission_id) REFERENCES permissions(permission_id) ON DELETE CASCADE,
    UNIQUE KEY uk_role_resource_permission (role_id, resource_id, permission_id),
    INDEX idx_role_id (role_id),
    INDEX idx_resource_permission (resource_id, permission_id)
);

-- Role groups within applications (for easier bulk role management)
CREATE TABLE role_groups (
    group_id BIGINT PRIMARY KEY AUTO_INCREMENT,
    app_id BIGINT NOT NULL,
    group_code VARCHAR(100) NOT NULL,
    group_name VARCHAR(200) NOT NULL,
    group_description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (app_id) REFERENCES applications(app_id) ON DELETE CASCADE,
    UNIQUE KEY uk_group_app (app_id, group_code),
    INDEX idx_app_id (app_id)
);

-- Role-Group memberships (roles within the same application can belong to groups)
CREATE TABLE role_group_members (
    role_group_member_id BIGINT PRIMARY KEY AUTO_INCREMENT,
    role_id BIGINT NOT NULL,
    group_id BIGINT NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (role_id) REFERENCES roles(role_id) ON DELETE CASCADE,
    FOREIGN KEY (group_id) REFERENCES role_groups(group_id) ON DELETE CASCADE,
    UNIQUE KEY uk_role_group (role_id, group_id)
);

-- Cross-application role templates (optional: for creating similar roles across apps)
CREATE TABLE role_templates (
    template_id BIGINT PRIMARY KEY AUTO_INCREMENT,
    template_code VARCHAR(100) UNIQUE NOT NULL,
    template_name VARCHAR(200) NOT NULL,
    template_description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_template_code (template_code)
);

-- Template-based role creation mapping
CREATE TABLE role_template_mappings (
    mapping_id BIGINT PRIMARY KEY AUTO_INCREMENT,
    role_id BIGINT NOT NULL,
    template_id BIGINT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (role_id) REFERENCES roles(role_id) ON DELETE CASCADE,
    FOREIGN KEY (template_id) REFERENCES role_templates(template_id) ON DELETE CASCADE,
    UNIQUE KEY uk_role_template (role_id, template_id)
);

-- Audit trail for permission changes
CREATE TABLE audit_logs (
    audit_id BIGINT PRIMARY KEY AUTO_INCREMENT,
    table_name VARCHAR(100) NOT NULL,
    record_id BIGINT NOT NULL,
    action ENUM('INSERT', 'UPDATE', 'DELETE') NOT NULL,
    old_values JSON,
    new_values JSON,
    changed_by_user VARCHAR(255),
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ip_address VARCHAR(45),
    user_agent TEXT,
    
    INDEX idx_table_record (table_name, record_id),
    INDEX idx_changed_at (changed_at),
    INDEX idx_changed_by (changed_by_user)
);

-- =====================================================
-- SAMPLE DATA INSERTION
-- =====================================================

-- Insert sample applications
INSERT INTO applications (app_code, app_name, app_description) VALUES 
('PAYROLL_APP', 'Payroll Management System', 'System for managing payroll operations'),
('HR_APP', 'Human Resources System', 'System for HR operations'),
('FINANCE_APP', 'Finance Management System', 'System for financial operations');

-- Insert standard permissions
INSERT INTO permissions (permission_code, permission_name, permission_description) VALUES
('READ', 'Read', 'View/Read access to resources'),
('WRITE', 'Write', 'Create/Update access to resources'),
('DELETE', 'Delete', 'Delete access to resources'),
('EXECUTE', 'Execute', 'Execute operations on resources'),
('APPROVE', 'Approve', 'Approval permissions'),
('ADMIN', 'Admin', 'Administrative permissions');

-- Insert sample modules for each application
INSERT INTO modules (app_id, module_code, module_name, module_description) VALUES
-- Payroll App modules
(1, 'PAYROLL_PROC', 'Payroll Processing', 'Core payroll processing functionality'),
(1, 'PAYROLL_REPORTS', 'Payroll Reports', 'Payroll reporting and analytics'),
-- HR App modules
(2, 'EMPLOYEE_MGMT', 'Employee Management', 'Employee data management'),
(2, 'LEAVE_MGMT', 'Leave Management', 'Leave and attendance management'),
-- Finance App modules
(3, 'ACCOUNTS', 'Accounts', 'General accounting functionality'),
(3, 'BUDGET', 'Budget Management', 'Budget planning and tracking');

-- Insert sample resources
INSERT INTO resources (module_id, resource_code, resource_name, resource_type, resource_path) VALUES
-- Payroll resources
(1, 'PAYROLL_MAKER', 'Payroll Maker', 'PAGE', '/payroll/maker'),
(1, 'PAYROLL_CHECKER', 'Payroll Checker', 'PAGE', '/payroll/checker'),
(1, 'ERROR_CORRECTION', 'Input Error Correction', 'PAGE', '/payroll/error-correction'),
(2, 'PAYROLL_DASHBOARD', 'Payroll Dashboard', 'PAGE', '/payroll/dashboard'),
-- HR resources
(3, 'EMPLOYEE_LIST', 'Employee List', 'PAGE', '/hr/employees'),
(3, 'EMPLOYEE_PROFILE', 'Employee Profile', 'PAGE', '/hr/employee-profile'),
(4, 'LEAVE_REQUESTS', 'Leave Requests', 'PAGE', '/hr/leave-requests'),
-- Finance resources
(5, 'CHART_ACCOUNTS', 'Chart of Accounts', 'PAGE', '/finance/chart-accounts'),
(6, 'BUDGET_PLANNING', 'Budget Planning', 'PAGE', '/finance/budget-planning');

-- Link resources to permissions
INSERT INTO resource_permissions (resource_id, permission_id) VALUES
-- Payroll resources permissions
(1, 1), (1, 2), -- Payroll Maker: READ, WRITE
(2, 1), (2, 5), -- Payroll Checker: READ, APPROVE
(3, 1), (3, 2), (3, 3), -- Error Correction: READ, WRITE, DELETE
(4, 1), -- Dashboard: READ
-- HR resources permissions
(5, 1), (5, 2), -- Employee List: READ, WRITE 
(6, 1), (6, 2), -- Employee Profile: READ, WRITE
(7, 1), (7, 5), -- Leave Requests: READ, APPROVE
-- Finance resources permissions
(8, 1), (8, 2), -- Chart of Accounts: READ, WRITE
(9, 1), (9, 2), (9, 5); -- Budget Planning: READ, WRITE, APPROVE

-- Insert APPLICATION-SPECIFIC ROLES
-- Payroll App Roles
INSERT INTO roles (app_id, role_code, role_name, role_description, role_level) VALUES
(1, 'PAYROLL_SPECIALIST', 'Payroll Specialist', 'Entry level payroll specialist role', 1),
(1, 'PAYROLL_LEAD', 'Payroll Lead', 'Lead payroll specialist role', 2),
(1, 'PAYROLL_MANAGER', 'Payroll Manager', 'Payroll manager role', 3),
(1, 'PAYROLL_ADMIN', 'Payroll Admin', 'Payroll system administrator', 4);

-- HR App Roles  
INSERT INTO roles (app_id, role_code, role_name, role_description, role_level) VALUES
(2, 'HR_OFFICER', 'HR Officer', 'HR officer role', 1),
(2, 'HR_MANAGER', 'HR Manager', 'HR manager role', 2),
(2, 'HR_DIRECTOR', 'HR Director', 'HR director role', 3);

-- Finance App Roles
INSERT INTO roles (app_id, role_code, role_name, role_description, role_level) VALUES
(3, 'ACCOUNTANT', 'Accountant', 'Staff accountant role', 1),
(3, 'SENIOR_ACCOUNTANT', 'Senior Accountant', 'Senior accountant role', 2),
(3, 'FINANCE_MANAGER', 'Finance Manager', 'Finance manager role', 3),
(3, 'CFO', 'Chief Financial Officer', 'CFO role', 4);

-- Set up role hierarchy within each application
-- Payroll hierarchy
UPDATE roles SET parent_role_id = (SELECT role_id FROM (SELECT role_id FROM roles WHERE role_code = 'PAYROLL_SPECIALIST' AND app_id = 1) AS r1) WHERE role_code = 'PAYROLL_LEAD' AND app_id = 1;
UPDATE roles SET parent_role_id = (SELECT role_id FROM (SELECT role_id FROM roles WHERE role_code = 'PAYROLL_LEAD' AND app_id = 1) AS r1) WHERE role_code = 'PAYROLL_MANAGER' AND app_id = 1;
UPDATE roles SET parent_role_id = (SELECT role_id FROM (SELECT role_id FROM roles WHERE role_code = 'PAYROLL_MANAGER' AND app_id = 1) AS r1) WHERE role_code = 'PAYROLL_ADMIN' AND app_id = 1;

-- HR hierarchy
UPDATE roles SET parent_role_id = (SELECT role_id FROM (SELECT role_id FROM roles WHERE role_code = 'HR_OFFICER' AND app_id = 2) AS r1) WHERE role_code = 'HR_MANAGER' AND app_id = 2;
UPDATE roles SET parent_role_id = (SELECT role_id FROM (SELECT role_id FROM roles WHERE role_code = 'HR_MANAGER' AND app_id = 2) AS r1) WHERE role_code = 'HR_DIRECTOR' AND app_id = 2;

-- Finance hierarchy
UPDATE roles SET parent_role_id = (SELECT role_id FROM (SELECT role_id FROM roles WHERE role_code = 'ACCOUNTANT' AND app_id = 3) AS r1) WHERE role_code = 'SENIOR_ACCOUNTANT' AND app_id = 3;
UPDATE roles SET parent_role_id = (SELECT role_id FROM (SELECT role_id FROM roles WHERE role_code = 'SENIOR_ACCOUNTANT' AND app_id = 3) AS r1) WHERE role_code = 'FINANCE_MANAGER' AND app_id = 3;
UPDATE roles SET parent_role_id = (SELECT role_id FROM (SELECT role_id FROM roles WHERE role_code = 'FINANCE_MANAGER' AND app_id = 3) AS r1) WHERE role_code = 'CFO' AND app_id = 3;

-- Sample role permissions assignments
-- Payroll Specialist permissions
INSERT INTO role_permissions (role_id, resource_id, permission_id) VALUES
(1, 1, 1), (1, 1, 2), -- Payroll Maker: READ, WRITE
(1, 4, 1); -- Dashboard: READ

-- Payroll Lead permissions (inherits specialist + checker access)
INSERT INTO role_permissions (role_id, resource_id, permission_id) VALUES
(2, 1, 1), (2, 1, 2), -- Payroll Maker: READ, WRITE
(2, 2, 1), (2, 2, 5), -- Payroll Checker: READ, APPROVE
(2, 3, 1), (2, 3, 2), -- Error Correction: READ, WRITE
(2, 4, 1); -- Dashboard: READ

-- Payroll Manager permissions (full payroll access)
INSERT INTO role_permissions (role_id, resource_id, permission_id) VALUES
(3, 1, 1), (3, 1, 2), -- Payroll Maker: READ, WRITE
(3, 2, 1), (3, 2, 5), -- Payroll Checker: READ, APPROVE
(3, 3, 1), (3, 3, 2), (3, 3, 3), -- Error Correction: READ, WRITE, DELETE
(3, 4, 1); -- Dashboard: READ

-- Sample role groups
INSERT INTO role_groups (app_id, group_code, group_name, group_description) VALUES
(1, 'PAYROLL_STAFF', 'Payroll Staff', 'All payroll processing staff'),
(1, 'PAYROLL_MGMT', 'Payroll Management', 'Payroll management team'),
(2, 'HR_STAFF', 'HR Staff', 'HR department staff'),
(3, 'FINANCE_TEAM', 'Finance Team', 'Finance department team');

-- Role group memberships
INSERT INTO role_group_members (role_id, group_id) VALUES
(1, 1), (2, 1), -- Payroll Staff group
(3, 2), (4, 2), -- Payroll Management group
(5, 3), (6, 3), (7, 3), -- HR Staff group
(8, 4), (9, 4), (10, 4), (11, 4); -- Finance Team group

-- =====================================================
-- USEFUL VIEWS FOR EASIER QUERYING
-- =====================================================

-- View to get all permissions for a specific role
CREATE VIEW role_permissions_view AS
SELECT 
    r.role_id,
    r.role_code,
    r.role_name,
    a.app_code,
    a.app_name,
    m.module_code,
    m.module_name,
    res.resource_code,
    res.resource_name,
    res.resource_type,
    res.resource_path,
    p.permission_code,
    p.permission_name,
    rp.access_type
FROM roles r
JOIN applications a ON r.app_id = a.app_id AND a.is_active = TRUE
JOIN role_permissions rp ON r.role_id = rp.role_id AND rp.is_active = TRUE
JOIN resources res ON rp.resource_id = res.resource_id AND res.is_active = TRUE
JOIN modules m ON res.module_id = m.module_id AND m.is_active = TRUE
JOIN permissions p ON rp.permission_id = p.permission_id AND p.is_active = TRUE
WHERE r.is_active = TRUE;

-- View for application-specific role hierarchy
CREATE VIEW app_role_hierarchy AS
WITH RECURSIVE role_tree AS (
    SELECT r.role_id, r.role_code, r.role_name, r.parent_role_id, r.role_level, 0 as depth,
           CAST(r.role_code AS CHAR(1000)) as path,
           a.app_code, a.app_name, r.app_id
    FROM roles r
    JOIN applications a ON r.app_id = a.app_id AND a.is_active = TRUE
    WHERE r.parent_role_id IS NULL AND r.is_active = TRUE
    
    UNION ALL
    
    SELECT r.role_id, r.role_code, r.role_name, r.parent_role_id, r.role_level, rt.depth + 1,
           CONCAT(rt.path, ' -> ', r.role_code),
           rt.app_code, rt.app_name, r.app_id
    FROM roles r
    JOIN role_tree rt ON r.parent_role_id = rt.role_id
    WHERE r.is_active = TRUE
)
SELECT * FROM role_tree
ORDER BY app_code, depth, role_level;

-- View for application resources and their available permissions
CREATE VIEW app_resources_permissions AS
SELECT 
    a.app_code,
    a.app_name,
    m.module_code,
    m.module_name,
    r.resource_code,
    r.resource_name,
    r.resource_type,
    r.resource_path,
    p.permission_code,
    p.permission_name
FROM applications a
JOIN modules m ON a.app_id = m.app_id AND m.is_active = TRUE
JOIN resources r ON m.module_id = r.module_id AND r.is_active = TRUE
JOIN resource_permissions rp ON r.resource_id = rp.resource_id AND rp.is_active = TRUE
JOIN permissions p ON rp.permission_id = p.permission_id AND p.is_active = TRUE
WHERE a.is_active = TRUE
ORDER BY a.app_code, m.module_code, r.resource_code, p.permission_code;

-- =====================================================
-- INDEXES FOR PERFORMANCE
-- =====================================================

-- Additional performance indexes
CREATE INDEX idx_role_permissions_active ON role_permissions(role_id, is_active);
CREATE INDEX idx_roles_app_active ON roles(app_id, is_active, role_level);
CREATE INDEX idx_resources_active ON resources(module_id, is_active, resource_type);
CREATE INDEX idx_audit_logs_date ON audit_logs(table_name, changed_at);

-- =====================================================
-- SAMPLE QUERIES FOR COMMON OPERATIONS
-- =====================================================

/*
-- Get all applications and their roles
SELECT a.app_code, a.app_name, r.role_code, r.role_name, r.role_level
FROM applications a
JOIN roles r ON a.app_id = r.app_id
WHERE a.is_active = TRUE AND r.is_active = TRUE
ORDER BY a.app_code, r.role_level;

-- Get all permissions for a specific role
SELECT * FROM role_permissions_view 
WHERE role_code = 'PAYROLL_MANAGER'
ORDER BY module_code, resource_code, permission_code;

-- Get all resources available in a specific application
SELECT * FROM app_resources_permissions 
WHERE app_code = 'PAYROLL_APP'
ORDER BY module_code, resource_code, permission_code;

-- Check if a role has specific permission on a resource
SELECT COUNT(*) > 0 as has_permission
FROM role_permissions_view 
WHERE role_code = 'PAYROLL_LEAD'
AND app_code = 'PAYROLL_APP'
AND resource_code = 'PAYROLL_CHECKER'
AND permission_code = 'APPROVE'
AND access_type = 'ALLOW';

-- Get role hierarchy for a specific application
SELECT * FROM app_role_hierarchy 
WHERE app_code = 'PAYROLL_APP'
ORDER BY depth, role_level;

-- Get all roles in a specific application
SELECT role_code, role_name, role_description, role_level
FROM roles r
JOIN applications a ON r.app_id = a.app_id
WHERE a.app_code = 'PAYROLL_APP'
AND r.is_active = TRUE
ORDER BY role_level;

-- Get all roles that have access to a specific resource
SELECT DISTINCT r.role_code, r.role_name, p.permission_code
FROM roles r
JOIN role_permissions rp ON r.role_id = rp.role_id
JOIN resources res ON rp.resource_id = res.resource_id
JOIN permissions p ON rp.permission_id = p.permission_id
WHERE res.resource_code = 'PAYROLL_MAKER'
AND r.is_active = TRUE AND rp.is_active = TRUE
ORDER BY r.role_code, p.permission_code;

-- Get all resources accessible by roles in a role group
SELECT DISTINCT rg.group_code, rg.group_name, res.resource_code, res.resource_name, p.permission_code
FROM role_groups rg
JOIN role_group_members rgm ON rg.group_id = rgm.group_id
JOIN role_permissions rp ON rgm.role_id = rp.role_id
JOIN resources res ON rp.resource_id = res.resource_id  
JOIN permissions p ON rp.permission_id = p.permission_id
WHERE rg.group_code = 'PAYROLL_STAFF'
AND rg.is_active = TRUE AND rgm.is_active = TRUE AND rp.is_active = TRUE
ORDER BY res.resource_code, p.permission_code;
*/

-- =====================================================
-- EXTERNAL USER INTEGRATION NOTES
-- =====================================================

/*
For SSO/External User Management Integration:

1. Use external user ID/email as the key for permission checks
2. Map external users to roles via your application logic
3. Sample integration queries:

-- Check user permissions (to be called from application with external user ID)
-- Replace 'USER_ROLE_CODE' with the role assigned to user from external system
SELECT COUNT(*) > 0 as has_permission
FROM role_permissions_view 
WHERE role_code = 'USER_ROLE_CODE'  -- From external user management
AND app_code = 'TARGET_APP'
AND resource_code = 'TARGET_RESOURCE'
AND permission_code = 'TARGET_PERMISSION'
AND access_type = 'ALLOW';

-- Get user's accessible resources (application will provide user's assigned roles)
SELECT DISTINCT resource_code, resource_name, resource_path, permission_code
FROM role_permissions_view 
WHERE role_code IN ('ROLE1', 'ROLE2')  -- User's roles from external system
AND app_code = 'TARGET_APP'
AND access_type = 'ALLOW'
ORDER BY resource_name, permission_code;

This model assumes your application will:
- Authenticate users via SSO/external system
- Retrieve user's assigned role codes from external system
- Use role codes to query permissions from this RBAC model
- Cache permissions for performance if needed
*/