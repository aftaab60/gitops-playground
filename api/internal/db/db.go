package db

import (
	"database/sql"
	"fmt"

	"gitops-tracker-api/internal/config"
	_ "github.com/lib/pq"
)

func Connect(cfg *config.Config) (*sql.DB, error) {
	dsn := fmt.Sprintf(
		"host=%s port=%s user=%s password=%s dbname=%s sslmode=disable",
		cfg.DBHost, cfg.DBPort, cfg.DBUser, cfg.DBPassword, cfg.DBName,
	)
	db, err := sql.Open("postgres", dsn)
	if err != nil {
		return nil, err
	}
	if err := db.Ping(); err != nil {
		return nil, err
	}
	return db, nil
}

func Migrate(db *sql.DB) error {
	statements := []string{
		`CREATE TABLE IF NOT EXISTS users (
			id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
			email TEXT UNIQUE NOT NULL,
			password_hash TEXT NOT NULL,
			created_at TIMESTAMPTZ DEFAULT NOW()
		)`,
		`CREATE TABLE IF NOT EXISTS progress (
			user_id UUID REFERENCES users(id) ON DELETE CASCADE,
			phase_index INTEGER NOT NULL,
			item_index INTEGER NOT NULL,
			completed BOOLEAN DEFAULT FALSE,
			updated_at TIMESTAMPTZ DEFAULT NOW(),
			PRIMARY KEY (user_id, phase_index, item_index)
		)`,
	}
	for _, s := range statements {
		if _, err := db.Exec(s); err != nil {
			return err
		}
	}
	return nil
}
