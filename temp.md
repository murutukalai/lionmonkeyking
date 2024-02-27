```
-- Sample data for the role table
INSERT INTO role (title, is_active, created_by, created_by_id) 
VALUES 
('Admin', true, 'AdminUser', 123),
('Moderator', true, 'ModUser', 456),
('User', true, 'RegularUser', 789),
('Guest', true, 'GuestUser', 101112),
('Editor', true, 'EditorUser', 131415),
('Developer', true, 'DevUser', 161718),
('Tester', true, 'TestUser', 192021),
('Analyst', true, 'AnalysisUser', 222324),
('Manager', true, 'ManagerUser', 252627),
('Support', true, 'SupportUser', 282930);

-- Sample data for the privilege table
INSERT INTO privilege (title, module, object, action)
VALUES 
('Create Post', 'Blog', 'Post', 'Create'),
('Edit Post', 'Blog', 'Post', 'Edit'),
('Delete Post', 'Blog', 'Post', 'Delete'),
('Create User', 'User Management', 'User', 'Create'),
('Edit User', 'User Management', 'User', 'Edit'),
('Delete User', 'User Management', 'User', 'Delete'),
('Create Comment', 'Blog', 'Comment', 'Create'),
('Edit Comment', 'Blog', 'Comment', 'Edit'),
('Delete Comment', 'Blog', 'Comment', 'Delete'),
('Manage Roles', 'Access Control', 'Role', 'Manage');

-- Sample data for the role_privilege table
INSERT INTO role_privilege (role_id, privilege_id, excluded_ids)
VALUES 
(1, 1, NULL),
(1, 2, NULL),
(1, 3, NULL),
(2, 1, NULL),
(2, 2, NULL),
(3, 1, NULL),
(3, 7, '4,5'),
(4, 7, NULL),
(5, 2, NULL),
(5, 8, '9,10');
```
