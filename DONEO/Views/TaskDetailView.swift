import SwiftUI
import PhotosUI

struct TaskDetailView: View {
    let task: DONEOTask
    @Bindable var viewModel: ProjectChatViewModel
    @State private var showingTaskInfo = false
    @State private var showingSubtasks = false
    @State private var messageText = ""
    @State private var showingAttachmentOptions = false
    @State private var showingImagePicker = false
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @FocusState private var isInputFocused: Bool
    @Environment(\.dismiss) private var dismiss

    // Task messages (filtered from project messages that reference this task)
    private var taskMessages: [Message] {
        viewModel.project.messages.filter { message in
            message.referencedTask?.taskId == task.id
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Subtareas row
            subtareasRow

            // Separator
            Divider()
                .padding(.horizontal, 16)

            // Conversación row
            conversacionRow

            // Separator
            Divider()
                .padding(.horizontal, 16)

            // Chat area
            chatArea

            // Input bar
            inputBar
        }
        .background(Color(uiColor: .systemBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                // Tappable title - navigates to task info
                Button {
                    showingTaskInfo = true
                } label: {
                    Text(task.title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .navigationDestination(isPresented: $showingTaskInfo) {
            TaskInfoView(task: task, viewModel: viewModel)
        }
        .sheet(isPresented: $showingSubtasks) {
            SubtasksSheet(task: task, viewModel: viewModel)
        }
        .confirmationDialog("Adjuntar", isPresented: $showingAttachmentOptions) {
            Button {
                showingImagePicker = true
            } label: {
                Label("Fotos y Videos", systemImage: "photo.on.rectangle")
            }
            Button {
                // Camera
            } label: {
                Label("Cámara", systemImage: "camera")
            }
            Button {
                // Document
            } label: {
                Label("Documento", systemImage: "doc")
            }
            Button("Cancelar", role: .cancel) { }
        }
        .photosPicker(isPresented: $showingImagePicker, selection: $selectedPhotoItem, matching: .images)
        .onChange(of: selectedPhotoItem) { _, newValue in
            Task {
                if let item = newValue,
                   let data = try? await item.loadTransferable(type: Data.self) {
                    let taskRef = TaskReference(task: task)
                    viewModel.sendMessage(content: "📷", referencedTask: taskRef)
                }
                selectedPhotoItem = nil
            }
        }
    }

    // MARK: - Subtareas Row

    private var subtareasRow: some View {
        Button {
            showingSubtasks = true
        } label: {
            HStack(spacing: 12) {
                // Pink/red checklist icon
                RoundedRectangle(cornerRadius: 8)
                    .fill(Theme.primary.opacity(0.15))
                    .frame(width: 36, height: 36)
                    .overlay {
                        Image(systemName: "checklist")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Theme.primary)
                    }

                Text("Subtareas")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.primary)

                // Count
                let completed = task.subtasks.filter { $0.isDone }.count
                let total = task.subtasks.count
                if total > 0 {
                    Text("\(completed)/\(total)")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.primary)
                }

                Spacer()

                // Add button
                Button {
                    addSubtask()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 32, height: 32)
                        .background(Color(uiColor: .tertiarySystemBackground))
                        .clipShape(Circle())
                }

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Conversación Row

    private var conversacionRow: some View {
        HStack(spacing: 12) {
            // Green chat icon
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.green.opacity(0.15))
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.green)
                }

            Text("Conversación")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.primary)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Chat Area

    private var chatArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if taskMessages.isEmpty {
                    // Empty state
                    VStack(spacing: 12) {
                        Spacer()

                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 50))
                            .foregroundStyle(Color.secondary.opacity(0.3))

                        Text("Sin mensajes aún")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.secondary)

                        Text("Inicia la conversación sobre esta tarea")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.secondary.opacity(0.7))

                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 300)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(taskMessages) { message in
                            TaskMessageBubble(
                                message: message,
                                isCurrentUser: message.isFromCurrentUser
                            )
                            .id(message.id)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .onChange(of: taskMessages.count) { _, _ in
                if let lastMessage = taskMessages.last {
                    withAnimation {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 10) {
            // + Attachment button
            Button {
                showingAttachmentOptions = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Theme.primary)
                    .frame(width: 36, height: 36)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(Circle())
            }

            // Text field
            TextField("Escribe un mensaje...", text: $messageText)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .focused($isInputFocused)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20))

            // Camera button
            Button {
                // Camera action
            } label: {
                Image(systemName: "camera.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.primary)
            }

            // Mic or Send button
            if messageText.trimmingCharacters(in: .whitespaces).isEmpty {
                Button {
                    // Voice recording
                } label: {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Theme.primary)
                }
            } else {
                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(Theme.primary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(uiColor: .systemBackground))
    }

    // MARK: - Actions

    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }

        let taskRef = TaskReference(task: task)
        viewModel.sendMessage(content: text, referencedTask: taskRef)

        messageText = ""
    }

    private func addSubtask() {
        let alert = UIAlertController(title: "Nueva Subtarea", message: nil, preferredStyle: .alert)
        alert.addTextField { textField in
            textField.placeholder = "Título de la subtarea"
        }
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
        alert.addAction(UIAlertAction(title: "Agregar", style: .default) { _ in
            if let text = alert.textFields?.first?.text, !text.trimmingCharacters(in: .whitespaces).isEmpty {
                viewModel.addSubtask(to: task, title: text)
            }
        })

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            var topVC = rootVC
            while let presented = topVC.presentedViewController {
                topVC = presented
            }
            topVC.present(alert, animated: true)
        }
    }
}

// MARK: - Task Message Bubble

struct TaskMessageBubble: View {
    let message: Message
    let isCurrentUser: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isCurrentUser { Spacer(minLength: 60) }

            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                if !isCurrentUser {
                    Text(message.sender.displayFirstName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.primary)
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

// MARK: - Task Info View (WhatsApp style)

struct TaskInfoView: View {
    let task: DONEOTask
    @Bindable var viewModel: ProjectChatViewModel

    var body: some View {
        List {
            // Header
            Section {
                VStack(spacing: 12) {
                    Circle()
                        .fill(Theme.primaryLight)
                        .frame(width: 80, height: 80)
                        .overlay {
                            Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 36))
                                .foregroundStyle(task.isDone ? .green : Theme.primary)
                        }

                    Text(task.title)
                        .font(.system(size: 20, weight: .bold))
                        .multilineTextAlignment(.center)

                    if let dueDate = task.dueDate {
                        Text(dueDate.formatted(.dateTime.month(.wide).day().year()))
                            .font(.system(size: 15))
                            .foregroundStyle(task.isOverdue ? .red : .secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .listRowBackground(Color.clear)
            }

            // Notes/Instructions
            if let notes = task.notes, !notes.isEmpty {
                Section("Instrucciones") {
                    Text(notes)
                        .font(.system(size: 15))
                }
            }

            // Assignees
            if !task.assignees.isEmpty {
                Section("\(task.assignees.count) Asignado\(task.assignees.count == 1 ? "" : "s")") {
                    ForEach(task.assignees) { assignee in
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Theme.primaryLight)
                                .frame(width: 44, height: 44)
                                .overlay {
                                    Text(assignee.avatarInitials)
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(Theme.primary)
                                }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(assignee.displayName)
                                    .font(.system(size: 16, weight: .medium))
                                Text(assignee.phoneNumber)
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            // Subtasks summary
            if !task.subtasks.isEmpty {
                Section {
                    let completed = task.subtasks.filter { $0.isDone }.count
                    HStack {
                        Image(systemName: "checklist")
                            .foregroundStyle(.secondary)
                        Text("Subtareas")
                        Spacer()
                        Text("\(completed)/\(task.subtasks.count)")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Attachments
            if !task.attachments.isEmpty {
                Section("Multimedia y Documentos") {
                    let images = task.attachments.filter { $0.type == .image }
                    let docs = task.attachments.filter { $0.type == .document }

                    if !images.isEmpty {
                        HStack {
                            Image(systemName: "photo.fill")
                                .foregroundStyle(Theme.primary)
                            Text("Fotos")
                            Spacer()
                            Text("\(images.count)")
                                .foregroundStyle(.secondary)
                        }
                    }

                    if !docs.isEmpty {
                        HStack {
                            Image(systemName: "doc.fill")
                                .foregroundStyle(Theme.primary)
                            Text("Documentos")
                            Spacer()
                            Text("\(docs.count)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // Actions
            Section {
                Button {
                    viewModel.toggleTaskStatus(task)
                } label: {
                    HStack {
                        Spacer()
                        Text(task.isDone ? "Marcar como pendiente" : "Marcar como completada")
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("Info de Tarea")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Subtasks Sheet

struct SubtasksSheet: View {
    let task: DONEOTask
    @Bindable var viewModel: ProjectChatViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(task.subtasks) { subtask in
                    HStack(spacing: 12) {
                        Button {
                            viewModel.toggleSubtaskStatus(task, subtask)
                        } label: {
                            Image(systemName: subtask.isDone ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 22))
                                .foregroundStyle(subtask.isDone ? .green : Color.secondary.opacity(0.4))
                        }

                        Text(subtask.title)
                            .font(.system(size: 16))
                            .strikethrough(subtask.isDone)
                            .foregroundStyle(subtask.isDone ? .secondary : .primary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Subtareas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Listo") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        TaskDetailView(
            task: DONEOTask(title: "Instalar herrajes de gabinetes", subtasks: [
                Subtask(title: "Subtarea 1", isDone: true),
                Subtask(title: "Subtarea 2", isDone: true),
                Subtask(title: "Subtarea 3"),
                Subtask(title: "Subtarea 4"),
                Subtask(title: "Subtarea 5")
            ]),
            viewModel: ProjectChatViewModel(project: Project(name: "Test"))
        )
    }
}
