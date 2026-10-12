# Backup and recovery

Set `BACKUP_DESTINATION` to storage outside the Incus container. `backup.sh`
creates a PostgreSQL custom dump, selected persistent files, checksums and a
manifest, then uses rsync to that destination. Its failure means there is no
confirmed off-container backup.

`restore.sh BACKUP_DIR` requires `CONFIRM_RESTORE=RESTORE_AUTHENTIK`, verifies
checksums, stops Authentik services, restores files and database, then starts
the stack. Verify health and login manually afterwards.
