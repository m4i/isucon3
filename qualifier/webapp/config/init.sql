ALTER TABLE memos ADD header varchar(20000);
UPDATE memos SET header = SUBSTRING_INDEX(content, '\n', 1);
