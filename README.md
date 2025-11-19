# 🔥 Ignis Groups

**Ignis Groups** is a **lightweight group and job queue system** built for [Ignis Roleplay](https://ignis-rp.com) and designed to integrate seamlessly with the **[summit_phone](https://github.com/Nathan-FiveM/summit_phone)**.  
It provides a persistent, synced, and phone-driven party system used for team-based jobs such as **House Robberies, Sanitation, Fishing, PostOp, and Taco runs.**

---

## ✨ Features

- 🔗 **Fully integrated** with `summit_phone`
- 👥 Create, join, and leave player groups
- 🔒 Optional password-protected groups
- 📞 Phone-based group management UI
- 🧭 Shared group blips and job tracking
- 🕹️ Job queue and cooldown management
- 📱 In-app notifications via `summit_phone:sendNotification`
- 🧩 Exportable API for other scripts (Rep / Tablet / Job resources)
- 🧠 Debug tools with `sv_debug 1`

---

## 📁 File Structure

```
ignis_groups/
├── fxmanifest.lua
├── config.lua
├── shared.lua
├── client/
│   └── client.lua
└── server/
    ├── server.lua
    └── server_queue.lua
```

---

## ⚙️ Configuration

All global settings can be edited in **`config.lua`**:
- Default group and job limits per activity  
- Cooldowns between jobs  
- State identifiers used to bind with job scripts  

```lua
Config.DefaultGroupLimit = 4

Config.JobPlayerLimits = {
    taco = 6,
    houserobbery = 12,
    sanitation = 16,
}

Config.GroupPlayerLimits = {
    taco = 2,
    sanitation = 4,
}
```

---

## Dependencies

### Required
| Dependency | Description |
|-----------|-------------|
| **[QBCore Framework](https://github.com/qbcore-framework)** *or* **qbox** | Primary framework |
| **[ox_lib](https://github.com/overextended/ox_lib)** | Zones and notifications (if configured) |
| **[summit_phone](https://github.com/Nathan-FiveM/summit_phone)** | Displays job stages to players |

---

## 🚀 Exports

You can access the group system programmatically from any server script:

| Export | Returns | Description |
|--------|----------|-------------|
| `GetGroupByMembers(source)` | `(group, groupId)` | Returns the group a player belongs to |
| `GetGroupLeader(groupId)` | `number` | Returns the leader’s server ID |
| `getGroupMembers(groupId)` | `table` | Returns an array of member server IDs |
| `getGroupSize(groupId)` | `number` | Returns current group size |
| `setJobStatus(groupId, stages)` | `void` | Marks a group as busy and updates job stages |
| `resetJobStatus(groupId)` | `void` | Resets a group’s job status |
| `pNotifyGroup(groupId, title, msg, icon?, color?, time?)` | `void` | Sends a phone notification to all members |
| `GroupEvent(groupId, event, args?)` | `void` | Triggers a client event for every member |
| `isGroupLeader(source, groupId)` | `boolean` | Checks if the player is the group leader |
| `DestroyGroup(groupId)` | `void` | Disbands a group and updates all UIs |
| `GetAllGroups()` | `table` | Returns all active groups |

Example usage:
```lua
local group, id = exports['ignis_groups']:GetGroupByMembers(source)
if group then
    exports['ignis_groups']:pNotifyGroup(id, 'Mission Ready', 'Get to the van!')
end
```

---

## 🔧 Commands

| Command | Description |
|----------|-------------|
| `/mygroup` | Prints your current group info |
| `/printgroup [id]` | Prints the group data for a given player |
| `/printgroups` | Lists all current groups (server-side) |

Enable debug printing with:
```
set sv_debug 1
```

---

## 🔄 Integration Notes

- **summit_phone** handles all NUI updates (Groups app).  
- Job scripts can queue groups using the `ignis_groups:server:readyForJob` event.

---

## 🧩 How to Integrate with Job Scripts

You can use Ignis Groups inside any job or activity script to make it group-compatible.

### ✅ Get Player’s Group

```lua
local group, id = exports['ignis_groups']:GetGroupByMembers(source)
if not group then
    TriggerClientEvent('QBCore:Notify', source, 'You must be in a group to start this job!', 'error')
    return
end
```

### 🚦 Start a Group Job

```lua
local stages = {
    { id = 1, name = 'Drive to the pickup location', isDone = false },
    { id = 2, name = 'Collect the goods', isDone = false },
    { id = 3, name = 'Deliver to destination', isDone = false },
}

exports['ignis_groups']:setJobStatus(id, stages)
```

### 🧭 Update Job Stage

```lua
stages[1].isDone = true
exports['ignis_groups']:setJobStatus(id, stages)
```

### 🧹 Reset Job Status

```lua
exports['ignis_groups']:resetJobStatus(id)
```

### 📱 Notify All Members

```lua
exports['ignis_groups']:pNotifyGroup(id, 'Mission Complete', 'Well done team!')
```

### 🧨 Trigger Client Events for the Whole Group

```lua
exports['ignis_groups']:GroupEvent(id, 'client:eventName', { arg1, arg2 })
```

---

## 🧰 Credits

Developed by **Nathan-FiveM for Ignis Roleplay**  
🔥 *Ignite Your Roleplay*