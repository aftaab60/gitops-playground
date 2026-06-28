package models

// Curriculum is the fixed study plan shared across all users.
var Curriculum = []Phase{
	{
		Title: "Phase 0 — Local environment setup",
		Days:  "Day 1 AM",
		Items: []string{
			"Install Docker (or Docker Desktop / Colima)",
			"Install kubectl",
			"Install a local cluster: kind (recommended) or minikube",
			"Install Helm + confirm git and a GitHub account",
			"Lab 0a: create a cluster (kind create cluster --name gitops)",
			"Lab 0b: verify with kubectl get nodes (node Ready)",
			"Lab 0c: create a GitHub repo named gitops-playground",
		},
	},
	{
		Title: "Phase 1 — Kubernetes + GitOps foundations",
		Days:  "Day 1 PM",
		Items: []string{
			"Learn core objects: Pod, Deployment, Service, Namespace, ConfigMap",
			"Learn kubectl basics: get, describe, apply -f, logs, port-forward",
			"Understand GitOps: declarative, version-controlled, continuously reconciled",
			"Lab 1a: write deployment.yaml + service.yaml for nginx",
			"Lab 1b: apply them and port-forward to nginx in the browser",
			"Lab 1c: delete a pod, watch Kubernetes recreate it (reconciliation)",
		},
	},
	{
		Title: "Phase 2 — Argo CD core",
		Days:  "Days 2–3",
		Items: []string{
			"Install Argo CD (create namespace + apply install.yaml)",
			"Install the Argo CD CLI and log into the UI (port-forward + admin password)",
			"Learn the Application object (repo/path → cluster/namespace)",
			"Learn sync (manual vs automated), self-heal, and prune",
			"Understand health status vs sync status",
			"Lab 2a: push nginx manifests to gitops-playground",
			"Lab 2b: create an Application via UI, then again via YAML",
			"Lab 2c: enable auto-sync + self-heal; change replicas in Git and watch it reconcile",
			"Lab 2d: edit the live Deployment with kubectl and watch self-heal revert it",
		},
	},
	{
		Title: "Phase 3 — Argo CD beyond the basics",
		Days:  "Days 4–5",
		Items: []string{
			"Deploy a Helm chart and a Kustomize app as Applications",
			"Learn the App-of-Apps pattern",
			"Learn AppProjects (repo/cluster/namespace guardrails)",
			"Learn sync waves and pre/post-sync hooks",
			"Learn ApplicationSets (generate many Apps from a template)",
			"Lab 3a: restructure repo into dev/ staging/ prod/ Kustomize overlays",
			"Lab 3b: create 3 Applications by hand, then replace with one ApplicationSet",
			"Lab 3c: add a sync wave so a ConfigMap is created before the Deployment",
		},
	},
	{
		Title: "Phase 4 — Kargo",
		Days:  "Days 6–8",
		Items: []string{
			"Install Kargo locally (quickstart install.sh: cert-manager + Argo CD + Kargo)",
			"Install the Kargo CLI and put it on your PATH",
			"Learn Project, Warehouse, Freight",
			"Learn Stage, Promotion, and promotion steps",
			"Learn Freight verification / gates",
			"Lab 4a: run the official Kargo Quickstart end to end; log into the UI",
			"Lab 4b: define a Warehouse watching a public image (e.g. nginx)",
			"Lab 4c: create dev/staging/prod Stages wired to your Argo CD Applications",
			"Lab 4d: set promotion steps to bump the image tag, commit, and sync Argo CD",
			"Lab 4e: promote the same Freight dev → staging → prod",
			"Lab 4f: add a manual approval / verification gate before prod",
		},
	},
	{
		Title: "Phase 5 — Capstone + consolidation",
		Days:  "Days 9–10",
		Items: []string{
			"Assemble: one repo, dev/staging/prod overlays",
			"Argo CD (via ApplicationSet) managing all three environments",
			"Kargo Warehouse → Stages pipeline auto-promoting new image tags with a prod gate",
			"Write a one-page README explaining the full flow",
			"Stretch: add a Helm chart as a second Warehouse source",
			"Stretch: add an AnalysisRun verification step",
			"Stretch: break an image tag on purpose and roll back by re-promoting older Freight",
		},
	},
}

type Phase struct {
	Title string   `json:"title"`
	Days  string   `json:"days"`
	Items []string `json:"items"`
}

type ProgressItem struct {
	PhaseIndex int  `json:"phase_index"`
	ItemIndex  int  `json:"item_index"`
	Completed  bool `json:"completed"`
}

type CurriculumResponse struct {
	Phases []PhaseWithProgress `json:"phases"`
}

type PhaseWithProgress struct {
	Title string         `json:"title"`
	Days  string         `json:"days"`
	Items []ItemProgress `json:"items"`
}

type ItemProgress struct {
	Index     int    `json:"index"`
	Text      string `json:"text"`
	Completed bool   `json:"completed"`
}
