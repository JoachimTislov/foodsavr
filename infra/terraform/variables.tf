variable "project_id" {
  type    = string
  default = "my-foodsavr-store"
}

variable "github_repository" {
  type    = string
  default = "JoachimTislov/foodsavr"
}

variable "web_app_id" {
  type    = string
  default = "1:514586238925:web:e562b8b85d97417f83ae84"
}

variable "web_api_key_id" {
  type    = string
  default = "2010adfb-c62e-4376-bf08-58fb4bd61747"
}

variable "app_check_enforcement" {
  description = "UNENFORCED | ENFORCED for Firestore, Auth, Storage. Register every client (incl. Android Play Integrity) before ENFORCED."
  type        = string
  default     = "UNENFORCED"
  validation {
    condition     = contains(["UNENFORCED", "ENFORCED"], var.app_check_enforcement)
    error_message = "Must be UNENFORCED or ENFORCED."
  }
}

# Firebase's auto-created allow-list for the browser key.
variable "web_api_key_services" {
  type = list(string)
  default = [
    "firebasedatabase.googleapis.com", "firebasehosting.googleapis.com", "firebaserules.googleapis.com",
    "sqladmin.googleapis.com", "cloudconfig.googleapis.com", "datastore.googleapis.com",
    "fcmregistrations.googleapis.com", "firebase.googleapis.com", "firebaseappcheck.googleapis.com",
    "firebaseappdistribution.googleapis.com", "firebaseapphosting.googleapis.com",
    "firebaseapptesters.googleapis.com", "firebasedataconnect.googleapis.com",
    "firebaseinappmessaging.googleapis.com", "firebaseinstallations.googleapis.com",
    "firebaseml.googleapis.com", "firebaseremoteconfig.googleapis.com",
    "firebaseremoteconfigrealtime.googleapis.com", "firebasestorage.googleapis.com",
    "firebasevertexai.googleapis.com", "firestore.googleapis.com", "identitytoolkit.googleapis.com",
    "logging.googleapis.com", "mlkit.googleapis.com", "play.googleapis.com", "securetoken.googleapis.com",
  ]
}
