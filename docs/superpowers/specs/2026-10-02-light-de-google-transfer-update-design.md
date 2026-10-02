---
name: light-de-google transfer update design
description: Design for updating the light-de-google guide to reflect the unavailability of the Google Transfer tool for standard accounts.
type: project
---

# Design: Updating light-de-google Transfer Instructions

## Context
The Google [Transfer Your Content](https://takeout.google.com/transfer) tool is currently only available to authorized Google Workspace for Education accounts. Users with standard Gmail accounts encounter an error when attempting to use it. The `light-de-google` guide currently instructs users to use this tool, which is no longer a viable path for most.

## Goal
Update the `light-to-google` guide to provide working alternatives for standard Google accounts, ensuring a smooth migration path for Drive and Mail.

## Proposed Approaches

### 1. The "Shared Folder" Method (Primary for Drive)
For Google Drive data:
1. Create a migration folder in the old account.
2. Move all data to be migrated into this folder.
3. Share the folder with the new Gmail account (Editor access).
4. In the new account, copy the files/folders to ensure the new account becomes the owner.

### 2. The "Standard Google Takeout" Method (Primary for Mail)
For Gmail and other data:
1. Use [Google Takeout](https://takeout.google.com/) to create a data archive.
2. Download the archive (e.g., `.mbox` for email).
3. Import the data into the new account/client.

## Implementation Details

### File: `light-de-google/01-overview.md`
*   Add a warning/notice: "Note: The Google Transfer tool is restricted to Workspace for Education accounts. For standard Gmail accounts, use the 'Shared Folder' or 'Standard Takeout' methods described in the guide."

### File: `light-de-google/03-migration.md`
*   Remove references to the restricted `takeout.google.com/transfer` tool.
*   Replace with the "Shared Folder" workflow for Drive migration.
*   Replace with the "Standard Google Takeout" workflow for Mail migration.

## Success Criteria
*   The guide no longer recommends a broken tool for standard users.
*   The instructions for the "Shared Folder" and "Standard Takeout" methods are clear and actionable.
*   The migration process for both Drive and Mail remains documented and functional.
