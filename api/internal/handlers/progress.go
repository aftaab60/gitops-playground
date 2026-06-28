package handlers

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"net/http"

	"gitops-tracker-api/internal/middleware"
	"gitops-tracker-api/internal/models"
)

type ProgressHandler struct {
	db *sql.DB
}

func NewProgressHandler(db *sql.DB) *ProgressHandler {
	return &ProgressHandler{db: db}
}

// GetCurriculum returns the full curriculum without user-specific progress (public).
func (h *ProgressHandler) GetCurriculum(w http.ResponseWriter, r *http.Request) {
	resp := models.CurriculumResponse{}
	for _, phase := range models.Curriculum {
		p := models.PhaseWithProgress{Title: phase.Title, Days: phase.Days}
		for i, item := range phase.Items {
			p.Items = append(p.Items, models.ItemProgress{Index: i, Text: item})
		}
		resp.Phases = append(resp.Phases, p)
	}
	writeJSON(w, http.StatusOK, resp)
}

// GetProgress returns the curriculum merged with the authenticated user's completion state.
func (h *ProgressHandler) GetProgress(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserIDFromContext(r.Context())

	rows, err := h.db.Query(
		`SELECT phase_index, item_index, completed FROM progress WHERE user_id = $1`,
		userID,
	)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal error")
		return
	}
	defer rows.Close()

	done := map[string]bool{}
	for rows.Next() {
		var pi, ii int
		var completed bool
		if err := rows.Scan(&pi, &ii, &completed); err == nil && completed {
			done[fmt.Sprintf("%d_%d", pi, ii)] = true
		}
	}

	resp := models.CurriculumResponse{}
	for pi, phase := range models.Curriculum {
		p := models.PhaseWithProgress{Title: phase.Title, Days: phase.Days}
		for ii, item := range phase.Items {
			p.Items = append(p.Items, models.ItemProgress{
				Index:     ii,
				Text:      item,
				Completed: done[fmt.Sprintf("%d_%d", pi, ii)],
			})
		}
		resp.Phases = append(resp.Phases, p)
	}
	writeJSON(w, http.StatusOK, resp)
}

// UpdateProgress upserts a single checkbox state for the authenticated user.
func (h *ProgressHandler) UpdateProgress(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserIDFromContext(r.Context())

	var item models.ProgressItem
	if err := json.NewDecoder(r.Body).Decode(&item); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	_, err := h.db.Exec(`
		INSERT INTO progress (user_id, phase_index, item_index, completed, updated_at)
		VALUES ($1, $2, $3, $4, NOW())
		ON CONFLICT (user_id, phase_index, item_index)
		DO UPDATE SET completed = $4, updated_at = NOW()
	`, userID, item.PhaseIndex, item.ItemIndex, item.Completed)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal error")
		return
	}

	writeJSON(w, http.StatusOK, item)
}
