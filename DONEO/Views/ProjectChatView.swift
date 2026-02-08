import SwiftUI
import PhotosUI

struct ProjectChatView: View {
    @State private var viewModel: ProjectChatViewModel
    @State private var showingProjectInfo = false
    @State private var showingAddTask = false
    @State private var showingTasks = true  // Start expanded
    @State private var messageText = ""
    @FocusState private var isInputFocused: Bool
    @Environment(\.dismiss) private var dismiss

    init(project: Project) {
        _viewModel = State(initialValue: ProjectChatViewModel(project: project))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Collapsible tasks section at top
            tasksHeader

            if showingTasks && !viewModel.tasks.isEmpty {
                tasksList
            }

            // Chat messages
            chatArea

            // Message input
            messageInputBar
        }
        .background(Color(uiColor: .systemBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                headerView
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingProjectInfo = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 18))
                        .foregroundStyle(Theme.primary)
                }
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .sheet(isPresented: $showingProjectInfo) {
            ProjectInfoSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $showingAddTask) {
            SimpleAddTaskSheet(viewModel: viewModel)
        }
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: 1) {
            Text(viewModel.project.name)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Text("\(viewModel.project.members.count) miembros")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Tasks Header (Collapsible)

    private var tasksHeader: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showingTasks.toggle()
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "checklist")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.primary)

                Text("Tareas")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)

                // Progress
                let completed = viewModel.completedTasks.count
                let total = viewModel.tasks.count
                if total > 0 {
                    Text("\(completed)/\(total)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(completed == total ? .green : Theme.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(completed == total ? Color.green.opacity(0.15) : Theme.primaryLight)
                        .clipShape(Capsule())
                }

                Spacer()

                // Add task button
                Button {
                    showingAddTask = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.primary)
                        .frame(width: 28, height: 28)
                        .background(Theme.primaryLight)
                        .clipShape(Circle())
                }

                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(showingTasks ? 180 : 0))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(uiColor: .secondarySystemBackground))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tasks List

    private var sortedTasks: [DONEOTask] {
        viewModel.tasks.sorted { (task1: DONEOTask, task2: DONEOTask) -> Bool in
            !task1.isDone && task2.isDone
        }
    }

    private var tasksList: some View {
        VStack(spacing: 0) {
            ForEach(sortedTasks) { task in
                SimpleTaskRow(task: task, viewModel: viewModel)

                if task.id != sortedTasks.last?.id {
                    Divider()
                        .padding(.leading, 52)
                }
            }
        }
        .background(Color(uiColor: .secondarySystemBackground))
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Chat Area

    private var chatArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    if viewModel.messages.isEmpty {
                        emptyChat
                    } else {
                        ForEach(viewModel.messages) { message in
                            SimpleChatBubble(message: message, viewModel: viewModel)
                                .id(message.id)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                if let lastMessage = viewModel.messages.last {
                    withAnimation {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var emptyChat: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 40))
                .foregroundStyle(Color.secondary.opacity(0.3))
            Text("Inicia la conversación")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(minHeight: 200)
    }

    // MARK: - Message Input

    private var messageInputBar: some View {
        HStack(spacing: 12) {
            // Text field
            TextField("Mensaje...", text: $messageText)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .focused($isInputFocused)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20))

            // Send button
            Button {
                sendMessage()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(messageText.trimmingCharacters(in: .whitespaces).isEmpty ? Color.secondary.opacity(0.3) : Theme.primary)
            }
            .disabled(messageText.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(uiColor: .systemBackground))
    }

    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        viewModel.sendMessage(content: text)
        messageText = ""
    }
}

// MARK: - Simple Task Row

struct SimpleTaskRow: View {
    let task: DONEOTask
    @Bindable var viewModel: ProjectChatViewModel

    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            Button {
                viewModel.toggleTaskStatus(task)
            } label: {
                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(task.isDone ? .green : Color.secondary.opacity(0.4))
            }
            .buttonStyle(.plain)

            // Task info
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.system(size: 15))
                    .strikethrough(task.isDone)
                    .foregroundStyle(task.isDone ? .secondary : .primary)
                    .lineLimit(1)

                if !task.assignees.isEmpty {
                    HStack(spacing: 4) {
                        HStack(spacing: -4) {
                            ForEach(task.assignees.prefix(2)) { assignee in
                                Circle()
                                    .fill(Theme.primaryLight)
                                    .frame(width: 16, height: 16)
                                    .overlay {
                                        Text(assignee.avatarInitials)
                                            .font(.system(size: 7, weight: .bold))
                                            .foregroundStyle(Theme.primary)
                                    }
                            }
                        }
                        Text(task.assignees.prefix(2).map { $0.displayFirstName }.joined(separator: ", "))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            // Due date if exists
            if let dueDate = task.dueDate {
                Text(formatDate(dueDate))
                    .font(.system(size: 12))
                    .foregroundStyle(task.isOverdue ? .red : .secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Hoy" }
        if calendar.isDateInTomorrow(date) { return "Mañana" }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }
}

// MARK: - Simple Chat Bubble

struct SimpleChatBubble: View {
    let message: Message
    @Bindable var viewModel: ProjectChatViewModel

    private var isCurrentUser: Bool {
        message.sender.id == viewModel.currentUser.id
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isCurrentUser { Spacer(minLength: 60) }

            if !isCurrentUser {
                Circle()
                    .fill(Theme.primaryLight)
                    .frame(width: 28, height: 28)
                    .overlay {
                        Text(message.sender.avatarInitials)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Theme.primary)
                    }
            }

            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                if !isCurrentUser {
                    Text(message.sender.displayFirstName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Text(message.content)
                    .font(.system(size: 15))
                    .foregroundStyle(isCurrentUser ? .white : .primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(isCurrentUser ? Theme.primary : Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                Text(message.timestamp.formatted(.dateTime.hour().minute()))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            if !isCurrentUser { Spacer(minLength: 60) }
        }
    }
}

// MARK: - Project Info Sheet

struct ProjectInfoSheet: View {
    @Bindable var viewModel: ProjectChatViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 12) {
                        Circle()
                            .fill(Theme.primaryLight)
                            .frame(width: 80, height: 80)
                            .overlay {
                                Text(viewModel.project.initials)
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundStyle(Theme.primary)
                            }

                        Text(viewModel.project.name)
                            .font(.system(size: 20, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }

                Section("Miembros") {
                    ForEach(viewModel.project.members) { member in
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Theme.primaryLight)
                                .frame(width: 40, height: 40)
                                .overlay {
                                    Text(member.avatarInitials)
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(Theme.primary)
                                }

                            VStack(alignment: .leading) {
                                Text(member.displayName)
                                    .font(.system(size: 15, weight: .medium))
                                Text(member.phoneNumber)
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section {
                    HStack {
                        Text("Tareas completadas")
                        Spacer()
                        Text("\(viewModel.completedTasks.count)/\(viewModel.tasks.count)")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Info del Proyecto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Listo") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Simple Add Task Sheet

struct SimpleAddTaskSheet: View {
    @Bindable var viewModel: ProjectChatViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var selectedAssignees: Set<UUID> = []
    @FocusState private var isTitleFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                // Title
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tarea")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)

                    TextField("¿Qué hay que hacer?", text: $title)
                        .font(.system(size: 17))
                        .padding(14)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .focused($isTitleFocused)
                }

                // Assignees
                VStack(alignment: .leading, spacing: 10) {
                    Text("Asignar a")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)

                    SimpleFlowLayout(spacing: 8) {
                        ForEach(viewModel.project.members) { member in
                            let isSelected = selectedAssignees.contains(member.id)
                            Button {
                                if isSelected {
                                    selectedAssignees.remove(member.id)
                                } else {
                                    selectedAssignees.insert(member.id)
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(isSelected ? Color.white.opacity(0.3) : Theme.primaryLight)
                                        .frame(width: 24, height: 24)
                                        .overlay {
                                            Text(member.avatarInitials)
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundStyle(isSelected ? .white : Theme.primary)
                                        }
                                    Text(member.displayFirstName)
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(isSelected ? Theme.primary : Color(uiColor: .secondarySystemBackground))
                                .foregroundStyle(isSelected ? .white : .primary)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Spacer()
            }
            .padding(20)
            .navigationTitle("Nueva Tarea")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Crear") {
                        createTask()
                    }
                    .fontWeight(.semibold)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                isTitleFocused = true
            }
        }
    }

    private func createTask() {
        let assignees = viewModel.project.members.filter { selectedAssignees.contains($0.id) }
        viewModel.addTask(title: title, assignees: assignees)
        dismiss()
    }
}

// MARK: - Simple Flow Layout

struct SimpleFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), proposal: .init(frame.size))
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        let maxWidth = proposal.width ?? .infinity
        var frames: [CGRect] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }

            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: y + rowHeight), frames)
    }
}

#Preview {
    NavigationStack {
        ProjectChatView(project: Project(
            name: "Renovacion Centro",
            members: MockDataService.allUsers,
            tasks: [
                DONEOTask(title: "Comprar materiales", assignees: [MockDataService.allUsers[0]], status: .pending),
                DONEOTask(title: "Instalar ventanas", status: .pending),
                DONEOTask(title: "Pintar paredes", status: .done)
            ]
        ))
    }
}
