import SwiftUI

struct OnboardingFlowView: View {
    struct Question: Identifiable {
        let id = UUID()
        let prompt: String
        let options: [String]
    }

    let onComplete: (OnboardingProfile) -> Void

    @State private var index = 0
    @State private var selectedAnswers: [String] = Array(repeating: "", count: 4)

    private let questions: [Question] = [
        Question(prompt: "What are you praying about right now?", options: ["Family", "Anxiety", "Purpose", "Work", "Relationships", "Health"]),
        Question(prompt: "How do you want to grow?", options: ["Consistency", "Courage", "Peace", "Discipline", "Service"]),
        Question(prompt: "When do you want to show up?", options: ["Morning", "Lunch", "Evening"]),
        Question(prompt: "What usually gets in the way?", options: ["Forgetfulness", "Overwhelm", "Inconsistency", "Distraction", "Not sure what to do"])
    ]

    private var currentQuestion: Question {
        questions[index]
    }

    private var canContinue: Bool {
        !selectedAnswers[index].isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(AppConstants.appName)
                .font(WWTypography.title(42))
                .foregroundStyle(WWColor.charcoal)

            Text(AppConstants.subtitle)
                .font(WWTypography.body(18).weight(.semibold))
                .foregroundStyle(WWColor.sapphire)

            ProgressView(value: Double(index + 1), total: Double(questions.count))
                .tint(WWColor.sapphire)

            WWCard {
                VStack(alignment: .leading, spacing: 16) {
                    Text(currentQuestion.prompt)
                        .font(WWTypography.section(28))
                        .foregroundStyle(WWColor.charcoal)

                    ForEach(currentQuestion.options, id: \.self) { option in
                        Button {
                            selectedAnswers[index] = option
                        } label: {
                            HStack {
                                Text(option)
                                    .font(WWTypography.body())
                                    .foregroundStyle(WWColor.charcoal)
                                Spacer()
                                if selectedAnswers[index] == option {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(WWColor.sapphire)
                                }
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            .background(selectedAnswers[index] == option ? WWColor.sage.opacity(0.25) : Color.white.opacity(0.6))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Button(index == questions.count - 1 ? "Generate Today Card" : "Continue") {
                guard canContinue else { return }
                if index < questions.count - 1 {
                    index += 1
                } else {
                    let profile = OnboardingProfile(
                        prayerFocus: selectedAnswers[0],
                        growthGoal: selectedAnswers[1],
                        reminderWindow: selectedAnswers[2],
                        blocker: selectedAnswers[3]
                    )
                    onComplete(profile)
                }
            }
            .buttonStyle(WWPrimaryButtonStyle())
            .disabled(!canContinue)
            .opacity(canContinue ? 1 : 0.45)
        }
        .padding(.top, 32)
    }
}
