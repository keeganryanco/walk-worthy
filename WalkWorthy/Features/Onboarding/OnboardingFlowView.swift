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
        case creationSprout
        case review
    }

    let onComplete: (OnboardingProfile) -> Void

    @State private var step: Step = .intro

    @State private var name = ""
    @State private var ageRange = ""
    @State private var growIn = ""
    @State private var blocker = ""
    @State private var growthVision = ""
    @State private var supportMode = ""
    
    @State private var reviewRating: Int? = nil

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
                        .padding(.top, 40)
                        .padding(.bottom, 24)
                }

                if step != .creationSprout {
                    bottomCTA
                        .padding(.horizontal, 28)
                        .padding(.bottom, 16)
                        .background(backgroundColor)
                }
            }
            .animation(.easeInOut(duration: 0.4), value: step)
        }
    }

    private var backgroundColor: Color {
        switch step {
        case .reminder:
            return WWColor.morningGold
        case .widget:
            return WWColor.surface
        case .creationSprout:
            return WWColor.darkBackground
        default:
            return WWColor.white
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .intro: introScreen
        case .name: nameScreen
        case .age: ageScreen
        case .bannerName: bannerNameScreen
        case .bannerTruth: bannerTruthScreen
        case .bannerChange: bannerChangeScreen
        case .growIn: optionsScreen(title: "what are you hoping\nto grow in?", options: growInOptions, selection: $growIn)
        case .blockers: optionsScreen(title: "What tends to\nget in the way?", options: blockerOptions, selection: $blocker)
        case .growthVision: optionsScreen(title: "What would growth\nlook like for you?", options: growthVisionOptions, selection: $growthVision)
        case .supportMode: optionsScreen(title: "how would you like\nTend to support you?", options: supportOptions, selection: $supportMode)
        case .method: methodScreen
        case .grounding: groundingScreen
        case .reminder: reminderScreen
        case .widget: widgetScreen
        case .creationSprout: creationSproutScreen
        case .review: reviewScreen
        }
    }

    // SCALED LAYOUTS: using standard font sizing, relative spacings, and responsive alignment
    // Old 60->40, 50->34, 44->28

    private var introScreen: some View {
        VStack(spacing: 20) {
            Image("TendMark")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .padding(.top, 20)

            Text("Welcome to Tend")
                .font(WWTypography.display(40))
                .foregroundStyle(WWColor.nearBlack)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 10)

            Text("pray. act. grow.")
                .font(WWTypography.heading(28))
                .foregroundStyle(WWColor.growGreen)

            Spacer()
                .frame(minHeight: 120)

            Text("turn your prayers into small\nsteps of real growth")
                .font(WWTypography.heading(26).italic())
                .foregroundStyle(WWColor.muted)
                .multilineTextAlignment(.center)
        }
        .frame(minHeight: UIScreen.main.bounds.height * 0.75, alignment: .top)
    }

    private var nameScreen: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 120)
            Text("what’s your name?")
                .font(WWTypography.display(34))
                .foregroundStyle(WWColor.nearBlack)
                .multilineTextAlignment(.center)

            TextField("Enter your name", text: $name)
                .font(WWTypography.heading(24))
                .foregroundStyle(WWColor.nearBlack)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(WWColor.surface)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(WWColor.growGreen, lineWidth: 1))
            Spacer()
        }
        .frame(minHeight: UIScreen.main.bounds.height * 0.75, alignment: .top)
    }

    private var ageScreen: some View {
        VStack(spacing: 16) {
            Text("how old are you?")
                .font(WWTypography.display(34))
                .foregroundStyle(WWColor.nearBlack)
                .multilineTextAlignment(.center)
                .padding(.bottom, 10)

            ForEach(ages, id: \.self) { item in
                TendPillButton(title: item, selected: ageRange == item) {
                    ageRange = item
                }
            }
            Spacer()
        }
        .frame(minHeight: UIScreen.main.bounds.height * 0.75, alignment: .top)
    }

    private var bannerNameScreen: some View {
        VStack(spacing: 12) {
            Spacer()
            Text("\(firstNameDisplay), your prayers matter.")
                .font(WWTypography.display(32))
                .foregroundStyle(WWColor.nearBlack)
                .multilineTextAlignment(.center)
            (
                Text("so does your ")
                    .font(WWTypography.display(32))
                    .foregroundStyle(WWColor.nearBlack)
                + Text("next step.")
                    .font(WWTypography.display(32))
                    .foregroundStyle(WWColor.growGreen)
            )
            .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(minHeight: UIScreen.main.bounds.height * 0.75)
    }

    private var bannerTruthScreen: some View {
        VStack(spacing: 30) {
            Spacer()
            Text("What you pray can shape\nhow you live.")
                .font(WWTypography.display(34))
                .foregroundStyle(WWColor.nearBlack)
                .multilineTextAlignment(.center)

            Text("Tend helps you turn\nyour prayers into your habits,\ndecisions, and daily life.")
                .font(WWTypography.heading(24))
                .foregroundStyle(WWColor.nearBlack)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(minHeight: UIScreen.main.bounds.height * 0.75)
    }

    private var bannerChangeScreen: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("What if prayer became\nthe start of real change?")
                .font(WWTypography.display(36))
                .foregroundStyle(WWColor.nearBlack)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(minHeight: UIScreen.main.bounds.height * 0.75)
    }

    private func optionsScreen(title: String, options: [String], selection: Binding<String>) -> some View {
        VStack(spacing: 16) {
            Text(title)
                .font(WWTypography.display(34))
                .foregroundStyle(WWColor.nearBlack)
                .multilineTextAlignment(.center)
                .padding(.bottom, 10)

            ForEach(options, id: \.self) { option in
                TendPillButton(title: option, selected: selection.wrappedValue == option) {
                    selection.wrappedValue = option
                }
            }
            Spacer()
        }
        .frame(minHeight: UIScreen.main.bounds.height * 0.75, alignment: .top)
    }

    private var methodScreen: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("Here’s how Tend works")
                .font(WWTypography.display(36))
                .foregroundStyle(WWColor.nearBlack)
                .multilineTextAlignment(.center)
                .padding(.bottom, 10)

            VStack(alignment: .leading, spacing: 16) {
                featureBullet(lead: "Pray", text: "about what matters")
                featureBullet(lead: "Reflect", text: "with Scripture")
                featureBullet(lead: "Choose", text: "one small step")
                featureBullet(lead: "Grow", text: "through daily faithfulness")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Spacer()
        }
        .frame(minHeight: UIScreen.main.bounds.height * 0.75)
    }

    private var groundingScreen: some View {
        VStack(spacing: 28) {
            Text("Faith grows when it’s lived.")
                .font(WWTypography.heading(32).italic())
                .foregroundStyle(WWColor.nearBlack)
                .multilineTextAlignment(.center)
                .padding(.top, 20)

            WWCard {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Tend is built around a simple truth:")
                        .font(WWTypography.heading(28))
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
                    .font(WWTypography.heading(26))
                    .foregroundStyle(WWColor.nearBlack)
                }
            }

            Image("TendMark")
                .resizable()
                .scaledToFit()
                .frame(width: 60, height: 60)
                .padding(.top, 10)
            
            Spacer()
        }
        .frame(minHeight: UIScreen.main.bounds.height * 0.75, alignment: .top)
    }

    private var reminderScreen: some View {
        VStack(spacing: 20) {
            Image("OnboardingReminderClock")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .padding(.top, 10)

            Text("Growth is easier when\nit stays in front of you.")
                .font(WWTypography.display(34))
                .foregroundStyle(WWColor.nearBlack)
                .multilineTextAlignment(.center)

            Text("Set a reminder to\nreturn to your prayer journey\nand take your next small step.")
                .font(WWTypography.heading(24).italic())
                .foregroundStyle(WWColor.nearBlack)
                .multilineTextAlignment(.center)
                .padding(.vertical, 8)

            Image("OnboardingNotificationsStack")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(.black.opacity(0.12), lineWidth: 1)
                )

            Spacer()
        }
        .frame(minHeight: UIScreen.main.bounds.height * 0.75, alignment: .top)
    }

    private var widgetScreen: some View {
        VStack(spacing: 24) {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.pink.opacity(0.55), Color.blue.opacity(0.65)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 380)
                .overlay {
                    Image("OnboardingNotificationsPhone")
                        .resizable()
                        .scaledToFit()
                        .padding(20)
                }
                .overlay(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.white.opacity(0.78))
                        .frame(height: 90)
                        .overlay(alignment: .leading) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\"Cast your cares on Him.\"\n1 Peter 5:7")
                                Text("Today’s step:\nTake 5 minutes to breathe and pray.")
                            }
                            .font(WWTypography.caption(14))
                            .foregroundStyle(Color.black)
                            .padding(.horizontal, 14)
                        }
                        .padding(14)
                }
                .padding(.top, 10)

            Text("Keep your journey\nclose.")
                .font(WWTypography.display(42))
                .foregroundStyle(WWColor.nearBlack)
                .multilineTextAlignment(.center)

            Text("See your current prayer, verse,\nand next step right\nfrom your home screen.")
                .font(WWTypography.heading(24).italic())
                .foregroundStyle(WWColor.nearBlack)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(minHeight: UIScreen.main.bounds.height * 0.75, alignment: .top)
    }
    
    // MARK: - New Screens (Creation Sprout Wow Moment + Review)

    @State private var sproutOpacity: Double = 0.0
    @State private var sproutScale: Double = 0.4
    @State private var sproutGlow: Double = 0.0

    private var creationSproutScreen: some View {
        VStack(spacing: 40) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(WWColor.growGreen.opacity(0.15))
                    .frame(width: 180, height: 180)
                    .scaleEffect(1.0 + sproutGlow)
                    .opacity(sproutOpacity)
                    .blur(radius: 20)
                
                Image("TendMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .scaleEffect(sproutScale)
                    .opacity(sproutOpacity)
                    .foregroundStyle(WWColor.growGreen) // Assuming icon can be styled or naturally green
            }
            
            Text("Creating your first journey...")
                .font(WWTypography.heading(24))
                .foregroundStyle(WWColor.white)
                .opacity(sproutOpacity)
            
            Spacer()
        }
        .frame(minHeight: UIScreen.main.bounds.height * 0.8)
        .onAppear {
            withAnimation(.easeOut(duration: 1.2)) {
                sproutOpacity = 1.0
                sproutScale = 1.0
            }
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                sproutGlow = 0.3
            }
            
            // Auto advance
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                withAnimation { step = .review }
            }
        }
    }

    private var reviewScreen: some View {
        VStack(spacing: 30) {
            Spacer()
            Text("How was this setup\nexperience?")
                .font(WWTypography.display(36))
                .foregroundStyle(WWColor.nearBlack)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 40) {
                Button {
                    reviewRating = 1
                } label: {
                    Image(systemName: "hand.thumbsdown.fill")
                        .font(.system(size: 40))
                        .foregroundColor(reviewRating == 1 ? .red : WWColor.muted.opacity(0.3))
                        .padding()
                        .background(WWColor.surface)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(reviewRating == 1 ? .red : .clear, lineWidth: 2))
                }
                
                Button {
                    reviewRating = 5
                } label: {
                    Image(systemName: "hand.thumbsup.fill")
                        .font(.system(size: 40))
                        .foregroundColor(reviewRating == 5 ? WWColor.growGreen : WWColor.muted.opacity(0.3))
                        .padding()
                        .background(WWColor.surface)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(reviewRating == 5 ? WWColor.growGreen : .clear, lineWidth: 2))
                }
            }
            
            if reviewRating != nil {
                Text("Thank you for your feedback.")
                    .font(WWTypography.caption(16))
                    .foregroundStyle(WWColor.muted)
            }
            
            Spacer()
        }
        .frame(minHeight: UIScreen.main.bounds.height * 0.75, alignment: .top)
    }

    // MARK: - Navigation & CTA

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
        case .intro: return "Get started"
        case .reminder: return "Enable reminders"
        case .widget: return "Create my journey"
        case .review: return "Finish"
        default: return "Next"
        }
    }

    private var currentButtonBackground: Color {
        switch step {
        case .reminder: return WWColor.surface
        default: return WWColor.growGreen
        }
    }

    private var currentButtonForeground: Color {
        switch step {
        case .reminder, .widget: return WWColor.nearBlack
        default: return .white
        }
    }

    private var canAdvance: Bool {
        switch step {
        case .name: return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .age: return !ageRange.isEmpty
        case .growIn: return !growIn.isEmpty
        case .blockers: return !blocker.isEmpty
        case .growthVision: return !growthVision.isEmpty
        case .supportMode: return !supportMode.isEmpty
        case .review: return reviewRating != nil
        default: return true
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
                .frame(width: 10, height: 10)
                .padding(.top, 10)
            (
                Text(lead).foregroundStyle(WWColor.growGreen) +
                Text(" \(text)").foregroundStyle(WWColor.nearBlack)
            )
            .font(WWTypography.heading(28))
        }
    }

    private func advance() {
        guard canAdvance else { return }

        if step == .review {
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
            withAnimation(.default) {
                step = next
            }
        }
    }
}
