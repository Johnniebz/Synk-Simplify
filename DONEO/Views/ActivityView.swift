import SwiftUI
import Observation

// MARK: - Activity View Model

@Observable
final class ActivityViewModel {
    private var dataService = MockDataService.shared

    var currentUser: User {
        dataService.currentUser
    }

    // Get project by ID
    func getProject(id: UUID) -> Project? {
        dataService.projects.first { $0.id == id }
    }

    // MARK: - Task Item

    struct TaskItem: Identifiable {
        let id: UUID
        let task: DONEOTask
        let project: Project

        var subtaskProgress: (done: Int, total: Int)? {
            let total = task.subtasks.count
            guard total > 0 else { return nil }
            let done = task.subtasks.filter { $0.isDone }.count
            return (done, total)
        }
    }

    // MARK: - All My Tasks (pending, assigned to me)

    var myPendingTasks: [TaskItem] {
        var items: [TaskItem] = []

        for project in dataService.projects {
            let tasks = project.tasks.filter { task in
                task.status == .pending &&
                task.assignees.contains(where: { $0.id == currentUser.id })
            }

            for task in tasks {
                items.append(TaskItem(id: task.id, task: task, project: project))
            }
        }

        // Sort by urgency: overdue first, then by due date
        return items.sorted { item1, item2 in
            let d1 = item1.task.dueDate ?? .distantFuture
            let d2 = item2.task.dueDate ?? .distantFuture
            if item1.task.isOverdue != item2.task.isOverdue {
                return item1.task.isOverdue
            }
            return d1 < d2
        }
    }

    // Overdue tasks
    var overdueTasks: [TaskItem] {
        myPendingTasks.filter { $0.task.isOverdue }
    }

    // Due today
    var todayTasks: [TaskItem] {
        myPendingTasks.filter { $0.task.isDueToday && !$0.task.isOverdue }
    }

    // Due this week (not today, not overdue)
    var thisWeekTasks: [TaskItem] {
        myPendingTasks.filter { item in
            guard let dueDate = item.task.dueDate else { return false }
            let calendar = Calendar.current
            let weekFromNow = calendar.date(byAdding: .day, value: 7, to: Date()) ?? Date()
            return !item.task.isOverdue && !item.task.isDueToday && dueDate <= weekFromNow
        }
    }

    // Later or no due date
    var laterTasks: [TaskItem] {
        myPendingTasks.filter { item in
            if item.task.isOverdue || item.task.isDueToday { return false }
            guard let dueDate = item.task.dueDate else { return true }
            let calendar = Calendar.current
            let weekFromNow = calendar.date(byAdding: .day, value: 7, to: Date()) ?? Date()
            return dueDate > weekFromNow
        }
    }

    // Stats
    var totalPending: Int { myPendingTasks.count }
    var overdueCount: Int { overdueTasks.count }
}

// MARK: - Activity View

struct ActivityView: View {
    @State private var viewModel = ActivityViewModel()
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(spacing: 0) {
                    // Header with greeting
                    headerSection
                        .padding(.bottom, 20)

                    // Main content
                    if viewModel.totalPending == 0 {
                        emptyState
                    } else {
                        tasksContent
                    }
                }
                .padding(.bottom, 40)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Actividad")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: UUID.self) { projectId in
                if let project = viewModel.getProject(id: projectId) {
                    ProjectChatView(project: project)
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 16) {
            // Greeting
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(greetingText)
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)

                    Text(viewModel.currentUser.displayFirstName)
                        .font(.system(size: 28, weight: .bold))
                }
                Spacer()

                // Avatar
                Circle()
                    .fill(Theme.primaryLight)
                    .frame(width: 50, height: 50)
                    .overlay {
                        Text(viewModel.currentUser.avatarInitials)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Theme.primary)
                    }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)

            // Quick stats
            HStack(spacing: 12) {
                quickStatCard(
                    count: viewModel.totalPending,
                    label: "Pendientes",
                    color: Theme.primary
                )

                if viewModel.overdueCount > 0 {
                    quickStatCard(
                        count: viewModel.overdueCount,
                        label: "Atrasadas",
                        color: .red
                    )
                }

                quickStatCard(
                    count: viewModel.todayTasks.count,
                    label: "Para Hoy",
                    color: .orange
                )
            }
            .padding(.horizontal, 20)
        }
    }

    private func quickStatCard(count: Int, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(color)

            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Buenos días" }
        if hour < 18 { return "Buenas tardes" }
        return "Buenas noches"
    }

    // MARK: - Tasks Content

    private var tasksContent: some View {
        VStack(spacing: 24) {
            // Overdue - Urgent!
            if !viewModel.overdueTasks.isEmpty {
                taskSection(
                    icon: "exclamationmark.triangle.fill",
                    title: "Atrasadas",
                    subtitle: "Requieren atención inmediata",
                    tasks: viewModel.overdueTasks,
                    urgencyColor: .red
                )
            }

            // Today
            if !viewModel.todayTasks.isEmpty {
                taskSection(
                    icon: "clock.fill",
                    title: "Para Hoy",
                    subtitle: "Vencen hoy",
                    tasks: viewModel.todayTasks,
                    urgencyColor: .orange
                )
            }

            // This week
            if !viewModel.thisWeekTasks.isEmpty {
                taskSection(
                    icon: "calendar",
                    title: "Esta Semana",
                    subtitle: "Próximos 7 días",
                    tasks: viewModel.thisWeekTasks,
                    urgencyColor: Theme.primary
                )
            }

            // Later
            if !viewModel.laterTasks.isEmpty {
                taskSection(
                    icon: "tray.full",
                    title: "Más Adelante",
                    subtitle: "Sin fecha próxima",
                    tasks: viewModel.laterTasks,
                    urgencyColor: .secondary
                )
            }
        }
    }

    // MARK: - Task Section

    private func taskSection(
        icon: String,
        title: String,
        subtitle: String,
        tasks: [ActivityViewModel.TaskItem],
        urgencyColor: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(urgencyColor)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.system(size: 17, weight: .semibold))

                        Text("(\(tasks.count))")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(urgencyColor)
                    }

                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal, 20)

            // Task cards
            VStack(spacing: 10) {
                ForEach(tasks) { item in
                    ActivityTaskCard(
                        item: item,
                        urgencyColor: urgencyColor,
                        onGoToChat: {
                            navigationPath.append(item.project.id)
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 60)

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 70))
                .foregroundStyle(.green.opacity(0.7))

            VStack(spacing: 8) {
                Text("¡Todo al día!")
                    .font(.system(size: 24, weight: .bold))

                Text("No tienes tareas pendientes.\nDisfruta tu tiempo libre.")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 40)
    }
}

// MARK: - Activity Task Card

struct ActivityTaskCard: View {
    let item: ActivityViewModel.TaskItem
    let urgencyColor: Color
    let onGoToChat: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Main content
            VStack(alignment: .leading, spacing: 10) {
                // Task title
                Text(item.task.title)
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                // Info row
                HStack(spacing: 12) {
                    // Due date
                    if let dueDate = item.task.dueDate {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.system(size: 12))
                            Text(formatDueDate(dueDate))
                                .font(.system(size: 13))
                        }
                        .foregroundStyle(item.task.isOverdue ? .red : .secondary)
                    }

                    // Subtasks progress
                    if let progress = item.subtaskProgress {
                        HStack(spacing: 4) {
                            Image(systemName: "checklist")
                                .font(.system(size: 12))
                            Text("\(progress.done)/\(progress.total)")
                                .font(.system(size: 13))
                        }
                        .foregroundStyle(progress.done == progress.total ? .green : .secondary)
                    }

                    // Assignees count
                    if item.task.assignees.count > 1 {
                        HStack(spacing: 4) {
                            Image(systemName: "person.2")
                                .font(.system(size: 12))
                            Text("\(item.task.assignees.count)")
                                .font(.system(size: 13))
                        }
                        .foregroundStyle(.secondary)
                    }
                }

                // Instructions preview
                if let notes = item.task.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(14)

            Divider()

            // Bottom action bar
            HStack(spacing: 0) {
                // Project info
                HStack(spacing: 8) {
                    Circle()
                        .fill(Theme.primaryLight)
                        .frame(width: 24, height: 24)
                        .overlay {
                            Text(item.project.initials)
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(Theme.primary)
                        }

                    Text(item.project.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                // Go to chat button
                Button(action: onGoToChat) {
                    HStack(spacing: 6) {
                        Image(systemName: "bubble.left.fill")
                            .font(.system(size: 12))
                        Text("Ir al Chat")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Theme.primary)
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(uiColor: .tertiarySystemGroupedBackground))
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(urgencyColor.opacity(0.3), lineWidth: item.task.isOverdue ? 2 : 0)
        )
    }

    private func formatDueDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Hoy" }
        if calendar.isDateInTomorrow(date) { return "Mañana" }
        if calendar.isDateInYesterday(date) { return "Ayer" }

        let daysUntil = calendar.dateComponents([.day], from: Date(), to: date).day ?? 0
        if daysUntil < 0 {
            return "Hace \(abs(daysUntil)) días"
        } else if daysUntil <= 7 {
            return date.formatted(.dateTime.weekday(.wide))
        }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }
}

// MARK: - Preview

#Preview {
    ActivityView()
}
