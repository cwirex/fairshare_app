## Feature: FairShare Local Sync (V1)

### 🎯 Core Principle

To provide a simple and reliable way for group members who are physically together to sync expense data without an internet connection. This initial version prioritizes **simplicity and robustness over complex, automatic conflict resolution**. The process is manually initiated and controlled by a single user (the **Host**) to create a temporary, single source of truth.

---

### 🧑‍🤝‍🧑 User Flow & UI Breakdown

The entire process happens within the context of a specific group that the users are already members of.

#### 1. Initiation

- Any group member inside the group's main screen sees a "Local Sync" button.
- Tapping this button presents two options: "**Start a Sync Session**" (become Host) or "**Join a Sync Session**" (become Client).

#### 2. The Host's Journey

1.  **Start Broadcasting:** The user who taps "**Start a Sync Session**" becomes the **Host**. Their device starts broadcasting its availability via Bluetooth/Wi-Fi Direct.
2.  **Lobby Screen (Host View):** The Host's screen changes to a "sync lobby." This screen displays:
    - The group name.
    - A list of group members who have successfully joined the session.
    - A status counter: "**3 of 5 members have joined.**"
    - A real-time "Sync Preview" section (starts empty).
    - A disabled "**Start Sync**" button.

#### 3. The Client's Journey

1.  **Start Scanning:** Users who tap "**Join a Sync Session**" will see a scanning screen.
2.  **Connect to Host:** The app automatically finds and connects to the Host's session for that specific group.
3.  **Lobby Screen (Client View):** The Client's screen changes to a simple waiting message: "**Connected! Waiting for [Host's Name] to start the sync.**"

#### 4. Pre-Sync Analysis (Automatic)

- As each Client joins, their device automatically sends a summary of its local changes (deltas) to the Host. This is **not** the full data, just metadata.
  - _Example payload from Client to Host:_ `{"new_expenses": 3, "edited_expenses": ["expense_id_123", "expense_id_456"], "deleted_expenses": ["expense_id_789"]}`.
- The Host's device collects this information from all connected Clients and analyzes it for potential conflicts.

#### 5. Sync Preview & Execution (Host's Decision)

1.  **Update UI:** The Host's "Sync Preview" section updates in real-time.
    - ✅ **No Conflicts:** The UI shows a clear message: "`Ready to sync: 5 new expenses, 2 payments.`" The "**Start Sync**" button becomes enabled.
    - ⚠️ **Potential Conflicts:** The UI shows a warning: "`Ready to sync: 5 new expenses, 2 payments.`\n`Warning: 3 items have been edited by multiple people. Syncing will use the newest version and may overwrite some changes.`" The "**Start Sync**" button becomes enabled, but perhaps with a warning color.
2.  **Host Starts Sync:** The Host presses the "**Start Sync**" button.
    - If there are conflicts, a confirmation dialog appears: "**Potential data loss detected. The most recent edit for each conflicting item will be kept. Do you want to continue?**" with "**Yes, Continue**" and "**Cancel**" buttons.
3.  **Transaction:** If the Host proceeds, the sync begins as a single transaction.

#### 6. Data Exchange & Completion

1.  **Host Consolidates:** The Host requests the full data for all changes from the Clients. It merges everything based on the V1 conflict resolution rule (see below). It now holds the "master" version of the group's data.
2.  **Host Distributes:** The Host sends the final, consolidated data set back to every connected Client.
3.  **Clients Apply:** Each Client receives the master data set and overwrites their local group data.
4.  **Confirmation:** All devices show a "**Sync Complete!**" message. The session is closed.

---

### ⚙️ Technical Logic & V1 Conflict Resolution

The goal is to avoid complex CRDTs or vector clocks in the first version.

- **Conflict Definition (V1):** A conflict occurs **only** when two or more users have edited or deleted the **same** expense/payment since their last sync. Adding new expenses is never a conflict.
- **Resolution Rule: "Host-Mediated Last Write Wins"**
  1.  **New Items:** All new expenses/payments from all users are simply added. We rely on **UUIDs** for each item to prevent duplicates.
  2.  **Conflicting Edits/Deletes:** If multiple users edited the same item, the Host's device will look at the `updated_at` timestamp for each version. **It will accept the change with the newest timestamp** and discard the others. This decision is final and is what gets synced to all devices.
- **Transactional Integrity:** The sync process must be **atomic (all or nothing)**. The Host will wait for a confirmation message from every Client that they have received and successfully saved the final data. If any Client fails, the Host will send an "abort" command to all devices to discard the sync attempt, ensuring no one is left in a partially synced state.

---

### 🚨 Handling Edge Cases

- **A User Drops Mid-Sync:** The Host's UI will show the user has disconnected. The Host can choose to proceed with the remaining connected users. The dropped user will have to sync later (either via another Local Sync or online).
- **Host Drops Mid-Sync:** The session is terminated for everyone. A message appears on all Client screens: "**Host has disconnected. The sync has been cancelled.**"
- **A User Tries to Join Late:** For V1, once the Host initiates the sync process (after pressing the "Start Sync" button), the session is locked and no new members can join. This simplifies the transaction logic significantly.
