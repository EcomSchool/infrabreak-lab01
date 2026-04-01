#!/bin/bash
# Run after key generation — inserts SSH keys into DB
ALICE_KEY=$(cat /tmp/alice_key)
CHARLIE_KEY=$(cat /tmp/charlie_key)

mysql -u root internaldb << SQL
INSERT INTO ssh_users (username, ssh_private_key, note) VALUES
('alice', '${ALICE_KEY}', 'Dev server access - decommissioned'),
('charlie', '${CHARLIE_KEY}', 'Monitoring access - active');
SQL
