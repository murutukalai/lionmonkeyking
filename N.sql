INSERT INTO task (project_id, employee_id, type, title, description, status, priority, due_date, created_by_id, created_by, is_closed, is_rejected) VALUES 
(101, 301, 'Bug Fix', 'Fix issue with login page', 'There is a bug causing login failures for users with special characters in their passwords.', 'Open', '5', '2024-02-25', 401, 'Alice', false, false),
(102, 302, 'Feature Development', 'Implement user profile page', 'Develop a user profile page where users can update their personal information.', 'In Progress', '4', '2024-03-10', 402, 'Bob', false, false),
(101, 303, 'Task', 'Write API documentation', 'Document the API endpoints and usage for the new authentication system.', 'Open', '3', '2024-03-05', 403, 'Charlie', false, false),
(103, 304, 'Maintenance', 'Optimize database queries', 'Identify and optimize slow-performing database queries to improve system performance.', 'Open', '5', NULL, 404, 'David', false, false),
(102, 305, 'Research', 'Evaluate third-party libraries', 'Research and evaluate third-party libraries for integrating a rich text editor into the application.', 'Open', '2', '2024-02-28', 405, 'Emma', false, false),
(104, 306, 'Testing', 'Perform regression testing', 'Execute regression tests to ensure that recent code changes have not introduced new bugs.', 'In Progress', '3', '2024-03-03', 406, 'Frank', false, false),
(101, 307, 'Documentation', 'Update user manual', 'Update the user manual with the latest features and improvements introduced in the recent release.', 'Open', '2', '2024-03-08', 407, 'Grace', false, false),
(103, 308, 'Meeting', 'Weekly project status meeting', 'Conduct the weekly project status meeting to discuss progress, challenges, and action items.', 'Open', '5', '2024-02-21', 408, 'Henry', false, false),
(105, 309, 'Deployment', 'Deploy version 2.0 to production', 'Plan and execute the deployment of version 2.0 to the production environment.', 'Open', '5', '2024-03-01', 409, 'Ivy', false, false),
(102, 310, 'Other', 'Miscellaneous task', 'This is a placeholder for any miscellaneous task that may arise during the project lifecycle.', 'Open', '1', NULL, 410, 'Jack', false, false);
