```sql
INSERT INTO blog_post (title, content, create_by, slug, status, seo_title, seo_keywords, seo_description, published_on) VALUES
    ('Introduction to SQL', 'SQL is a powerful language for managing relational databases.', 'Suriya', 'introduction-to-sql', 'P', 'SQL Basics', 'database, SQL, relational', 'Learn the basics of SQL programming.', '2024-01-01'),
    ('Web Development Trends', 'Explore the latest trends in web development and stay updated.', 'Askara', 'web-development-trends', 'P', 'Latest Web Dev Trends', 'web development, trends, programming', 'Stay informed about the latest trends in web development.', '2024-01-05'),
    ('Data Science Techniques', 'Learn advanced data science techniques for predictive analytics.', 'Sethu', 'data-science-techniques', 'D', 'Advanced Data Science', 'data science, analytics, techniques', 'Explore advanced techniques in data science for better predictions.', NULL),
    ('Python Programming Guide', 'A comprehensive guide to Python programming language.', 'Hari', 'python-programming-guide', 'P', 'Python Programming', 'python, programming, guide', 'Your go-to guide for learning Python programming.', '2024-01-10'),
    ('Cybersecurity Best Practices', 'Protect your systems with these cybersecurity best practices.', 'Akashiya', 'cybersecurity-best-practices', 'P', 'Cybersecurity Guidelines', 'cybersecurity, best practices, security', 'Implement these best practices to enhance your cybersecurity measures.', '2024-01-15'),
    ('Artificial Intelligence Basics', 'Understanding the basics of artificial intelligence and its applications.', 'Keerthana', 'ai-basics', 'D', 'AI Fundamentals', 'artificial intelligence, basics, machine learning', 'Get started with the fundamentals of artificial intelligence.', NULL),
    ('Mobile App Development Tips', 'Tips and tricks for successful mobile app development.', 'Surbhi', 'mobile-app-development-tips', 'P', 'App Development Tips', 'mobile app, development, tips', 'Enhance your mobile app development skills with these tips.', '2024-01-20'),
    ('Cloud Computing Overview', 'An overview of cloud computing and its benefits for businesses.', 'Peramesh', 'cloud-computing-overview', 'P', 'Cloud Computing', 'cloud computing, overview, technology', 'Explore the advantages of cloud computing for your business.', '2024-01-25'),
    ('Data Visualization Techniques', 'Effective techniques for visualizing data to gain insights.', 'Navaz', 'data-visualization-techniques', 'D', 'Data Visualization', 'data visualization, techniques, insights', 'Master the art of data visualization for better decision-making.', NULL),
    ('Frontend Frameworks Comparison', 'Comparing popular frontend frameworks for web development.', 'Pavithara', 'frontend-frameworks-comparison', 'P', 'Frontend Frameworks', 'frontend, frameworks, comparison', 'Choose the right frontend framework for your web development projects.', '2024-01-28');

INSERT INTO blog_tag (name, no_posts) VALUES
    ('SQL', 2),
    ('Web Development', 2),
    ('Data Science', 2),
    ('Python', 2),
    ('Cybersecurity', 1),
    ('Artificial Intelligence', 1),
    ('Mobile App Development', 1),
    ('Cloud Computing', 1),
    ('Data Visualization', 1),
    ('Frontend Frameworks', 1);

INSERT INTO blog_tags (post_id, tag_id) VALUES
    (1, 1),
    (2, 2),
    (3, 3),
    (4, 4),
    (5, 5),
    (6, 6),
    (7, 7),
    (8, 8),
    (9, 9),
    (10, 10);

INSERT INTO blog_analytic (post_id, tag_id, no_visits, no_hits) VALUES
    (1, 1, 500, 1000),
    (2, 2, 750, 1200),
    (3, 3, 300, 600),
    (4, 4, 600, 1100),
    (5, 5, 400, 800),
    (6, 6, 200, 400),
    (7, 7, 350, 700),
    (8, 8, 800, 1500),
    (9, 9, 250, 500),
    (10, 10, 700, 1300);
```

```sql
-- Example search query based on tags, keywords, and status, sorted by date
SELECT *
FROM blog_post
WHERE
    (tags @> '["tag1"]' OR tags @> '["tag2"]') -- Replace with your actual tag condition
    AND (keywords @> '["keyword1"]' OR keywords @> '["keyword2"]') -- Replace with your actual keyword condition
    AND status = 'published' -- Replace with your actual status condition
ORDER BY published_on DESC;

```
