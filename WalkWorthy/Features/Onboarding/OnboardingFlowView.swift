import SwiftUI

struct OnboardingFlowView: View {
    enum Step: Int, CaseIterable {
        case intro
        case name
        case age
        case bannerName
        case bannerTruth
        case bannerChange
        case growIn
        case blockers
        case growthVision
        case supportMode
        case method
        case grounding
        case reminder
        case widget
    }

    let onComplete: (OnboardingProfile) -> Void

    @State private var step: Step = .intro

    @State private var name = ""
    @State private var ageRange = ""
    @State private var growIn = ""
    @State private var blocker = ""
    @State private var growthVision = ""
    @State private var supportMode = ""

    private let ages = ["18-24", "25-34", "35-44", "45-54", "55+"]
    private let growInOptions = [
        "🕊️ peace", "⏱️ discipline", "🌟 confidence", "🌱 patience", "✝️ faith",
        "🧭 purpose", "🤝 relationships", "❤️‍🩹 healing", "🦁 courage", "🔁 consistency"
    ]
    private let blockerOptions = [
        "I overthink", "I lose consistency", "I feel stuck", "I forget", "I don’t know what step to take", "I pray, but don’t follow through"
    ]
    private let growthVisionOptions = [
        "more peace in my day", "better habits", "more trust in God", "more courage to act", "more consistency", "feel less stuck", "more clarity"
    ]
    private let supportOptions = ["daily check-ins", "few times a week", "when I need guidance most"]

    var body: some View {
        ZStack {
            backgroundColor
                .ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    stepContent
                        .padding(.horizontal, 24)
                        .padding(.top, 70)
                        .padding(.bottom, 24)
                }

                bottomCTA
                    .padding(.horizontal, 28)
                    .padding(.bottom, 26)
                    .background(backgroundColor)
            }
        }
    }

    private var backgroundColor: Color {
        switch step {
        case .reminder:
            return WWColor.morningGold
        case .widget:
            return WWColor.surface
        default:
            return WWColor.white
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .intro:
            introScreen
        case .name:
            nameScreen
        case .age:
            ageScreen
        case .bannerName:
            bannerNameScreen
        case .bannerTruth:
            bannerTruthScreen
        case .bannerChange:
            bannerChangeScreen
        case .growIn:
            optionsScreen(title: "what are you hoping\nto grow in?", options: growInOptions, selection: $growIn)
        case .blockers:
            optionsScreen(title: "What tends to\nget in the way?", options: blockerOptions, selection: $blocker)
        case .growthVision:
            optionsScreen(title: "What would growth\nlook like for you?", options: growthVisionOptions, selection: $growthVision)
        case .supportMode:
            optionsScreen(title: "how would you like\nTend to support you?", options: supportOptions, selection: $supportMode)
        case .method:
            methodScreen
        case .grounding:
            groundingScreen
        case .reminder:
            reminderScreen
        case .widget:
            widgetScreen
        }
    }

    private var introScreen: some View {
        VStack(spacing: 28) {
            Image("TendMark")
                .resizable()
                .scaledToFit()
                .frame(width: 130, height: 130)
                .padding(.top, 20)

            Text("Welcome to Tend")
                .font(WWTypography.display(60))
                .foregroundStyle(WWColor.nearBlack)
                .multilineTextAlignment(.center)

            Text("pray. act. grow.")
                .font(WWTypography.heading(40))
                .foregroundStyle(WWColor.growGreen)

            Spacer(minLength: 220)

            Text("turn your prayers into small\nsteps of real growth")
                .font(WWTypography.heading(44).italic())
                .foregroundStyle(WWColor.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 1100, alignment: .top)
    }

    private var nameScreen: some View {
        VStack(spacing: 32) {
            Text("what’s your name?")
                .font(WWTypography.display(50))
                .foregroundStyle(WWColor.nearBlack)
                .multilineTextAlignment(.center)
                .padding(.top, 310)

            TextField("Enter your name", text: $name)
                .font(WWTypography.heading(38))
                .foregroundStyle(WWColor.nearBlack)
                .padding(.horizontal, 26)
                .padding(.vertical, 18)
                .background(WWColor.surface)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(WWColor.growGreen, lineWidth: 1))

            Spacer(minLength: 540)
        }
    }

    private var ageScreen: some View {
        VStack(spacing: 18) {
            Text("how old are you?")
                .font(WWTypography.display(50))
                .foregroundStyle(WWColor.nearBlack)
                .multilineTextAlignment(.center)

            ForEach(ages, id: \.self) { item in
                TendPillButton(title: item, selected: ageRange == item) {
                    ageRange = item
                }
            }

            Spacer(minLength: 300)
        }
    }

    private var bannerNameScreen: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 330)
            Text("\(firstNameDisplay), your prayers matter.")
                .font(WWTypography.display(40))
                .foregroundStyle(WWColor.nearBlack)
                .multilineTextAlignment(.center)
            (
                Text("so does your ")
                    .font(WWTypography.display(40))
                    .foregroundStyle(WWColor.nearBlack)
                + Text("next step.")
                    .font(WWTypography.display(40))
                    .foregroundStyle(WWColor.growGreen)
            )
            .multilineTextAlignment(.center)
            Spacer(minLength: 420)
        }
    }

    private var bannerTruthScreen: some View {
        VStack(spacing: 50) {
            Spacer(minLength: 230)
            Text("What you pray can shape\nhow you live.")
                .font(WWTypography.display(50))
                .foregroundStyle(WWColor.nearBlack)
                .multilineTextAlignment(.center)

            Text("Tend helps you turn\nyour prayers into your habits,\ndecisions, and daily life.")
                .font(WWTypography.heading(35))
                .foregroundStyle(WWColor.nearBlack)
                .multilineTextAlignment(.center)
            Spacer(minLength: 420)
        }
    }

    private var bannerChangeScreen: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 360)
            Text("What if prayer became\nthe start of real change?")
                .font(WWTypography.display(50))
                .foregroundStyle(WWColor.nearBlack)
                .multilineTextAlignment(.center)
            Spacer(minLength: 520)
        }
    }

    private func optionsScreen(title: String, options: [String], selection: Binding<String>) -> some View {
        VStack(spacing: 18) {
            Text(title)
                .font(WWTypography.display(50))
                .foregroundStyle(WWColor.nearBlack)
                .multilineTextAlignment(.center)
                .padding(.bottom, 8)

            ForEach(options, id: \.self) { option in
                TendPillButton(title: option, selected: selection.wrappedValue == option) {
                    selection.wrappedValue = option
                }
            }

            Spacer(minLength: 220)
        }
    }

    private var methodScreen: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 300)
            Text("Here’s how Tend works")
                .font(WWTypography.display(50))
                .foregroundStyle(WWColor.nearBlack)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 10) {
                featureBullet(lead: "Pray", text: "about what matters")
                featureBullet(lead: "Reflect", text: "with Scripture")
                featureBullet(lead: "Choose", text: "one small step")
                featureBullet(lead: "Grow", text: "through daily\nfaithfulness")
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 440)
        }
    }

    private var groundingScreen: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 120)
            Text("Faith grows when it’s lived.")
                .font(WWTypography.heading(56).italic())
                .foregroundStyle(WWColor.nearBlack)
                .multilineTextAlignment(.center)

            WWCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Tend is built around a simple truth:")
                        .font(WWTypography.heading(49))
                        .foregroundStyle(WWColor.nearBlack)
                    (
                        Text("what ").foregroundStyle(WWColor.growGreen)
                        + Text("you pray can shape ")
                        + Text("how ").foregroundStyle(WWColor.growGreen)
                        + Text("you live, and small ")
                        + Text("faithful steps ").foregroundStyle(WWColor.growGreen)
                        + Text("can bear ")
                        + Text("real fruit").foregroundStyle(WWColor.growGreen)
                        + Text(" over time.")
                    )
                    .font(WWTypography.heading(45))
                    .foregroundStyle(WWColor.nearBlack)
                }
            }

            Image("TendMark")
                .resizable()
                .scaledToFit()
                .frame(width: 90, height: 90)

            Spacer(minLength: 220)
        }
    }

    private var reminderScreen: some View {
        VStack(spacing: 20) {
            Image("OnboardingReminderClock")
                .resizable()
                .scaledToFit()
                .frame(width: 170, height: 170)
                .padding(.top, 10)

            Text("Growth is easier when\nit stays in front of you.")
                .font(WWTypography.display(50))
                .foregroundStyle(WWColor.nearBlack)
                .multilineTextAlignment(.center)

            Text("Set a reminder to\nreturn to your prayer journey\nand take your next small step.")
                .font(WWTypography.heading(50).italic())
                .foregroundStyle(WWColor.nearBlack)
                .multilineTextAlignment(.center)

            Image("OnboardingNotificationsStack")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(.black.opacity(0.12), lineWidth: 1)
                )
                .padding(.top, 8)

            Spacer(minLength: 180)
        }
    }

    private var widgetScreen: some View {
        VStack(spacing: 20) {
            RoundedRectangle(cornerRadius: 44, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.pink.opacity(0.55), Color.blue.opacity(0.65)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 520)
                .overlay {
                    Image("OnboardingNotificationsPhone")
                        .resizable()
                        .scaledToFit()
                        .padding(30)
                }
                .overlay(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(.white.opacity(0.78))
                        .frame(height: 120)
                        .overlay(alignment: .leading) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("\"Cast your cares on Him.\"\n1 Peter 5:7")
                                Text("Today’s step:\nTake 5 minutes to breathe and pray.")
                            }
                            .font(WWTypography.caption(20))
                            .foregroundStyle(WWColor.nearBlack)
                            .padding(.horizontal, 14)
                        }
                        .padding(18)
                }
                .padding(.top, 4)

            Text("Keep your journey\nclose.")
                .font(WWTypography.display(66))
                .foregroundStyle(WWColor.nearBlack)
                .multilineTextAlignment(.center)

            Text("See your current prayer, verse,\nand next step right\nfrom your home screen.")
                .font(WWTypography.heading(50).italic())
                .foregroundStyle(WWColor.nearBlack)
                .multilineTextAlignment(.center)

            Spacer(minLength: 120)
        }
    }

    @ViewBuilder
    private var bottomCTA: some View {
        Button(currentButtonTitle) {
            advance()
        }
        .buttonStyle(
            WWPrimaryButtonStyle(
                background: currentButtonBackground,
                foreground: currentButtonForeground
            )
        )
        .disabled(!canAdvance)
        .opacity(canAdvance ? 1 : 0.45)
    }

    private var currentButtonTitle: String {
        switch step {
        case .intro:
            return "Get started"
        case .reminder:
            return "Enable reminders"
        case .widget:
            return "Add widget"
        default:
            return "Next"
        }
    }

    private var currentButtonBackground: Color {
        switch step {
        case .reminder:
            return WWColor.surface
        default:
            return WWColor.growGreen
        }
    }

    private var currentButtonForeground: Color {
        switch step {
        case .reminder, .widget:
            return WWColor.nearBlack
        default:
            return .white
        }
    }

    private var canAdvance: Bool {
        switch step {
        case .name:
            return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .age:
            return !ageRange.isEmpty
        case .growIn:
            return !growIn.isEmpty
        case .blockers:
            return !blocker.isEmpty
        case .growthVision:
            return !growthVision.isEmpty
        case .supportMode:
            return !supportMode.isEmpty
        default:
            return true
        }
    }

    private var firstNameDisplay: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Friend" }
        return trimmed
    }

    private func featureBullet(lead: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(WWColor.growGreen)
                .frame(width: 12, height: 12)
                .padding(.top, 10)
            (
                Text(lead)
                    .foregroundStyle(WWColor.growGreen)
                + Text(" \(text)")
                    .foregroundStyle(WWColor.nearBlack)
            )
            .font(WWTypography.heading(48))
        }
    }

    private func advance() {
        guard canAdvance else { return }

        if step == .widget {
            let profile = OnboardingProfile(
                name: firstNameDisplay,
                ageRange: ageRange,
                prayerFocus: growIn,
                growthGoal: growthVision,
                reminderWindow: supportMode,
                blocker: blocker,
                supportCadence: supportMode
            )
            onComplete(profile)
            return
        }

        if let next = Step(rawValue: step.rawValue + 1) {
            step = next
        }
    }
}
