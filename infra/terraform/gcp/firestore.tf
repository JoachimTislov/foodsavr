# ---------------------------------------------------------------------------
# Firestore (default) database, its security rules release (ADR 0010) and the
# composite indexes of firestore.indexes.json. Works on Spark. Existing
# resources are adopted through adopt_firebase.tf (scripts/infra/adopt.py
# firebase); the database is never deleted by Terraform.
# ---------------------------------------------------------------------------

locals {
  firestore_rules_file   = var.firestore_rules_file != "" ? var.firestore_rules_file : "${path.module}/../../../firestore.rules"
  firestore_indexes_file = var.firestore_indexes_file != "" ? var.firestore_indexes_file : "${path.module}/../../../firestore.indexes.json"
  firestore_indexes = {
    for index in jsondecode(file(local.firestore_indexes_file)).indexes :
    join("/", concat([index.collectionGroup, lookup(index, "queryScope", "COLLECTION")], [
      for field in index.fields : "${field.fieldPath}:${lookup(field, "order", lookup(field, "arrayConfig", ""))}"
    ])) => index
  }
}

resource "google_firestore_database" "default" {
  provider                = google-beta
  name                    = "(default)"
  location_id             = var.region
  type                    = "FIRESTORE_NATIVE"
  delete_protection_state = "DELETE_PROTECTION_ENABLED"
  deletion_policy         = "ABANDON"
  depends_on              = [google_project_service.apis]

  lifecycle {
    prevent_destroy = true
  }
}

# Rulesets are immutable: a rules change creates a new one and keeps the old
# ones as history (ABANDON), as `firebase deploy` does.
resource "google_firebaserules_ruleset" "firestore" {
  provider        = google-beta
  deletion_policy = "ABANDON"

  source {
    files {
      name    = "firestore.rules"
      content = file(local.firestore_rules_file)
    }
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [google_firestore_database.default]
}

# The provider cannot repoint a release, so a new ruleset replaces it (delete,
# then create a few seconds later). `make deploy-firestore-rules` remains the
# manual bypass; the next apply releases the tracked file again.
resource "google_firebaserules_release" "firestore" {
  provider = google-beta
  name     = "cloud.firestore"
  # The ruleset name is the ID or the full path depending on provider version.
  ruleset_name = "projects/${var.project_id}/rulesets/${regex("[^/]+$", google_firebaserules_ruleset.firestore.name)}"
}

resource "google_firestore_index" "composite" {
  provider    = google-beta
  for_each    = local.firestore_indexes
  database    = google_firestore_database.default.name
  collection  = each.value.collectionGroup
  query_scope = lookup(each.value, "queryScope", "COLLECTION")

  dynamic "fields" {
    for_each = each.value.fields
    content {
      field_path   = fields.value.fieldPath
      order        = lookup(fields.value, "order", null)
      array_config = lookup(fields.value, "arrayConfig", null)
    }
  }
}
