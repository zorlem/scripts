# A collection of small utility scripts for PostgreSQL

* create-instance.sh - Creates a new partition, filesystem and initializes a PostgreSQL cluster (instance). Also creates a directory for backups.
* postgresql-backup.sh - Creates a backup of PostgreSQL databases suitable for different backup agents (eg. Bacula). Dumps globals and enforces backup retention. Sends a mail with errors for automatic processing.
* postgresql-maintenance-scripts.sh - periodically run a set of SQL scripts stored in a directory

# A set of SQL scripts and shell wrappers for monitoring various aspects of a running PostgreSQL database

* bloat.sql - estimate the level of bloat (old tuples that need to be reclaimed by VACUUM) in PostgreSQL tablespaces
* getidletrans.sql - get the number of uncommitted transactions that are IDLE
* getlocks.sql - get the number of blocked transactions.
