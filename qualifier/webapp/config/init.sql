ALTER TABLE memos ADD header varchar(20000);
UPDATE memos SET header = SUBSTRING_INDEX(content, '\n', 1);

CREATE INDEX `memos_idx_is_private_created_at` ON memos (`is_private`, `created_at`);
CREATE INDEX `memos_idx_user_created_at` ON memos (`user`, `created_at`);
CREATE INDEX `memos_idx_user_is_private_created_at` ON memos (`user`, `is_private`, `created_at`);
