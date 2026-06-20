import re
import os

with open("apple/Shared/ContentView.swift", "r") as f:
    content = f.read()

# Define the boundaries of each struct
structs = re.finditer(r'(?:struct|func)\s+(\w+)(?:<.*?>)?\s*(?::\s*View)?\s*(?:->\s*Bool)?\s*\{', content)
starts = []
names = []
for m in structs:
    starts.append(m.start())
    names.append(m.group(1))

# Extract the handleDrop function and other parts
blocks = {}
for i in range(len(starts)):
    start_idx = starts[i]
    end_idx = starts[i+1] if i+1 < len(starts) else len(content)
    blocks[names[i]] = content[start_idx:end_idx]

import_statement = "import SwiftUI\nimport UniformTypeIdentifiers\n\n"

# Create individual files
files = {
    "ContentView.swift": ["ContentView", "handleDrop"],
    "SidebarView.swift": ["SidebarView"],
    "TaskRowView.swift": ["TaskRowView"],
    "TaskDetailView.swift": ["TaskDetailView"],
    "ProjectDetailView.swift": ["ProjectDetailView"],
    "AreaDetailView.swift": ["AreaDetailView"],
    "TrashView.swift": ["TrashView"],
    "SmartLists.swift": ["InboxView", "TodayView", "UpcomingView", "AnytimeView", "SomedayView", "LogbookView", "CreateTaskSheet"]
}

for filename, struct_names in files.items():
    filepath = f"apple/Shared/Views/{filename}" if filename != "ContentView.swift" else f"apple/Shared/{filename}"
    os.makedirs(os.path.dirname(filepath), exist_ok=True)
    with open(filepath, "w") as f:
        f.write(import_statement)
        for name in struct_names:
            if name in blocks:
                f.write(blocks[name] + "\n")

