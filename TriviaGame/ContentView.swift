import SwiftUI
import Combine

struct TriviaResponse: Decodable {
    let response_code: Int
    let results: [TriviaQuestion]
}

struct TriviaQuestion: Decodable {
    let category: String
    let type: String
    let difficulty: String
    let question: String
    let correct_answer: String
    let incorrect_answers: [String]
}

struct QuizItem: Identifiable {
    let id = UUID()
    let question: String
    let correct: String
    let answers: [String]
}

struct ContentView: View {
    @State private var count = "5"
    @State private var category = 0
    @State private var difficultyLevel = 1

    private var difficulty: String {
        ["easy", "medium", "hard"][difficultyLevel]
    }

    @State private var questionType = ""
    @State private var duration = 60
    @State private var questions: [QuizItem] = []
    @State private var selections: [UUID: String] = [:]
    @State private var playing = false
    @State private var submitted = false
    @State private var showScore = false
    @State private var loading = false
    @State private var errorMessage: String?
    @State private var remaining = 60
    @State private var deadline = Date()

    private let categories: [(String, Int)] = [
        ("Animals", 27),
        ("Any Category", 0),
        ("Art", 25),
        ("Celebrities", 26),
        ("Entertainment: Board Games", 16),
        ("Entertainment: Books", 10),
        ("Entertainment: Cartoon & Animations", 32),
        ("Entertainment: Comics", 29),
        ("Entertainment: Film", 11),
        ("Entertainment: Japanese Anime & Manga", 31),
        ("Entertainment: Music", 12),
        ("Entertainment: Musicals & Theatres", 13),
        ("Entertainment: Television", 14),
        ("Entertainment: Video Games", 15),
        ("General Knowledge", 9),
        ("Geography", 22),
        ("History", 23),
        ("Mythology", 20),
        ("Politics", 24),
        ("Science & Nature", 17),
        ("Science: Computers", 18),
        ("Science: Gadgets", 30),
        ("Science: Mathematics", 19),
        ("Sports", 21),
        ("Vehicles", 28)
    ]

    private var score: Int {
        questions.filter {
            selections[$0.id] == $0.correct
        }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            if !playing {
                optionsView
            } else {
                quizView
            }
        }
        .alert("Score", isPresented: $showScore) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("You scored \(score) out of \(questions.count)")
        }
        .alert(
            "Error",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: {
                    if !$0 { errorMessage = nil }
                }
            )
        ) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
        }
        .onReceive(
            Timer.publish(
                every: 0.25,
                on: .main,
                in: .common
            ).autoconnect()
        ) { _ in
            guard playing && !submitted else { return }

            remaining = max(
                0,
                Int(ceil(deadline.timeIntervalSinceNow))
            )

            if remaining == 0 {
                submit()
            }
        }
    }

    private var optionsView: some View {
        VStack(spacing: 0) {
            Text("Trivia Game")
                .font(.system(size: 25, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.top, 9)
                .padding(.bottom, 14)
                .background(
                    Color(
                        red: 0.12,
                        green: 0.48,
                        blue: 0.97
                    )
                )

            Form {
                Section {
                    TextField(
                        "Number of Questions",
                        text: $count
                    )
                    .keyboardType(.numberPad)

                    Picker(
                        "Select Category",
                        selection: $category
                    ) {
                        ForEach(categories, id: \.1) { item in
                            Text(item.0).tag(item.1)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.gray)

                    HStack(spacing: 8) {
                        Text(
                            "Difficulty: \(difficulty.capitalized)"
                        )
                        .foregroundStyle(.primary)
                        .fixedSize(
                            horizontal: true,
                            vertical: false
                        )

                        GeometryReader { geometry in
                            let diameter: CGFloat = 26
                            let trackWidth = max(
                                1,
                                geometry.size.width - diameter
                            )
                            let fraction =
                                CGFloat(difficultyLevel) / 2

                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color(white: 0.88))
                                    .frame(height: 4)

                                Capsule()
                                    .fill(Color.blue)
                                    .frame(
                                        width: diameter / 2
                                            + trackWidth * fraction,
                                        height: 4
                                    )

                                Circle()
                                    .fill(Color.white)
                                    .frame(
                                        width: diameter,
                                        height: diameter
                                    )
                                    .shadow(
                                        color: .black.opacity(0.18),
                                        radius: 2,
                                        y: 1
                                    )
                                    .offset(
                                        x: trackWidth * fraction
                                    )
                            }
                            .frame(height: 32)
                            .contentShape(Rectangle())
                            .highPriorityGesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { gesture in
                                        let position = min(
                                            max(
                                                gesture.location.x
                                                    - diameter / 2,
                                                0
                                            ),
                                            trackWidth
                                        )

                                        difficultyLevel = Int(
                                            (
                                                position
                                                    / trackWidth * 2
                                            ).rounded()
                                        )
                                    }
                            )
                        }
                        .frame(height: 32)
                    }

                    Picker(
                        "Select Type",
                        selection: $questionType
                    ) {
                        Text("Any Type").tag("")
                        Text("Multiple Choice").tag("multiple")
                        Text("True or False").tag("boolean")
                    }
                    .pickerStyle(.menu)
                    .tint(.gray)

                    Picker(
                        "Timer Duration",
                        selection: $duration
                    ) {
                        Text("30 seconds").tag(30)
                        Text("60 seconds").tag(60)
                        Text("120 seconds").tag(120)
                        Text("300 seconds").tag(300)
                        Text("1 hour").tag(3600)
                    }
                    .pickerStyle(.menu)
                    .tint(.gray)
                }
            }
            .scrollContentBackground(.hidden)
            .background(
                Color(
                    red: 0.96,
                    green: 0.96,
                    blue: 1
                )
            )

            bottomButton("Start Trivia") {
                Task {
                    await startTrivia()
                }
            }
            .disabled(loading)
        }
        .background(
            Color(
                red: 0.12,
                green: 0.48,
                blue: 0.97
            )
        )
    }

    private var quizView: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    playing = false
                    submitted = false
                } label: {
                    Label(
                        "Back",
                        systemImage: "chevron.left"
                    )
                }

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 9)

            Text("Time remaining: \(remaining)s")
                .font(.system(size: 24))
                .foregroundStyle(.black)
                .padding(.top, 15)
                .padding(.bottom, 16)

            ScrollView {
                VStack(
                    alignment: .leading,
                    spacing: 0
                ) {
                    ForEach(questions) { item in
                        VStack(
                            alignment: .leading,
                            spacing: 10
                        ) {
                            Text(item.question)
                                .font(
                                    .system(
                                        size: 16,
                                        weight: .semibold
                                    )
                                )
                                .foregroundStyle(.black)
                                .padding(.bottom, 4)

                            ForEach(
                                Array(item.answers.enumerated()),
                                id: \.offset
                            ) { index, answer in
                                Button {
                                    if !submitted {
                                        selections[item.id] = answer
                                    }
                                } label: {
                                    HStack(spacing: 8) {
                                        Text(
                                            "\(String(UnicodeScalar(65 + index)!)). \(answer)"
                                        )
                                        .foregroundStyle(.black)
                                        .multilineTextAlignment(
                                            .leading
                                        )

                                        Spacer(minLength: 2)

                                        if !submitted
                                            && selections[item.id] == answer {
                                            Image(
                                                systemName:
                                                    "checkmark.circle.fill"
                                            )
                                            .foregroundStyle(.green)
                                        } else if submitted
                                            && answer == item.correct {
                                            Image(
                                                systemName:
                                                    "checkmark.circle.fill"
                                            )
                                            .foregroundStyle(.green)
                                        } else if submitted
                                            && selections[item.id] == answer
                                            && answer != item.correct {
                                            Image(
                                                systemName:
                                                    "xmark.circle.fill"
                                            )
                                            .foregroundStyle(.red)
                                        }
                                    }
                                    .font(.system(size: 24))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 15)
                                    .frame(
                                        maxWidth: .infinity,
                                        alignment: .leading
                                    )
                                    .background(
                                        Color(
                                            red: 0.95,
                                            green: 0.95,
                                            blue: 0.96
                                        )
                                    )
                                    .clipShape(
                                        RoundedRectangle(
                                            cornerRadius: 8
                                        )
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 25)
                        .background(.white)
                        .padding(.bottom, 1)
                    }
                }
                .padding(.horizontal, 30)
                .background(
                    Color(
                        red: 0.96,
                        green: 0.96,
                        blue: 0.98
                    )
                )
            }

            bottomButton("Submit") {
                submit()
            }
        }
        .background(
            Color(
                red: 0.88,
                green: 1,
                blue: 0.89
            )
        )
    }

    private func bottomButton(
        _ title: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(loading ? "Loading..." : title)
                .font(
                    .system(
                        size: 15,
                        weight: .medium
                    )
                )
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    Color(
                        red: 0.15,
                        green: 0.86,
                        blue: 0.29
                    )
                )
                .clipShape(Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func submit() {
        guard !submitted else {
            showScore = true
            return
        }

        submitted = true
        showScore = true
    }

    @MainActor
    private func startTrivia() async {
        guard !loading else { return }

        loading = true
        defer { loading = false }

        let amount = min(
            50,
            max(1, Int(count) ?? 5)
        )

        // Exact questions supplied for the three categories.
        // Other settings use the live Open Trivia API.
        if let preset = presetQuestions(amount: amount) {
            questions = preset
            selections = [:]
            submitted = false
            remaining = duration
            deadline = Date().addingTimeInterval(
                TimeInterval(duration)
            )
            playing = true
            return
        }

        var components = URLComponents(
            string: "https://opentdb.com/api.php"
        )!

        var query = [
            URLQueryItem(
                name: "amount",
                value: String(amount)
            )
        ]

        if category != 0 {
            query.append(
                URLQueryItem(
                    name: "category",
                    value: String(category)
                )
            )
        }

        query.append(
            URLQueryItem(
                name: "difficulty",
                value: difficulty
            )
        )

        if !questionType.isEmpty {
            query.append(
                URLQueryItem(
                    name: "type",
                    value: questionType
                )
            )
        }

        components.queryItems = query

        do {
            let (data, _) = try await URLSession.shared.data(
                from: components.url!
            )

            let response = try JSONDecoder().decode(
                TriviaResponse.self,
                from: data
            )

            guard response.response_code == 0
                    && !response.results.isEmpty else {
                errorMessage =
                    "No questions are available for these options. Please try different settings."
                return
            }

            questions = response.results.map { item in
                let correct = decodeHTML(
                    item.correct_answer
                )

                let answers = (
                    item.incorrect_answers.map(decodeHTML)
                        + [correct]
                ).shuffled()

                return QuizItem(
                    question: decodeHTML(item.question),
                    correct: correct,
                    answers: answers
                )
            }

            selections = [:]
            submitted = false
            remaining = duration
            deadline = Date().addingTimeInterval(
                TimeInterval(duration)
            )
            playing = true
        } catch {
            errorMessage =
                "Unable to load trivia questions. Please check your connection and try again."
        }
    }

    private func presetQuestions(
        amount: Int
    ) -> [QuizItem]? {

        // SPORTS: 5 Easy Multiple Choice
        if category == 21
            && amount == 5
            && difficulty == "easy"
            && questionType == "multiple" {

            return [
                QuizItem(
                    question:
                        "Which of these teams has Jaromir Jagr not played for?",
                    correct: "New York Islanders",
                    answers: [
                        "Calgary Flames",
                        "New Jersey Devils",
                        "Dallas Stars",
                        "New York Islanders"
                    ]
                ),
                QuizItem(
                    question:
                        "When was the first official international game played?",
                    correct: "1872",
                    answers: [
                        "1880", "1863", "1865", "1872"
                    ]
                ),
                QuizItem(
                    question:
                        "Which of these NHL teams originally played in Atlanta?",
                    correct: "Calgary Flames",
                    answers: [
                        "St. Louis Blues",
                        "Minnesota Wild",
                        "Vancouver Canucks",
                        "Calgary Flames"
                    ]
                ),
                QuizItem(
                    question:
                        "What was the year of estabilishment of the Bari Italian Football Club?",
                    correct: "1908",
                    answers: [
                        "1945", "2014", "1895", "1908"
                    ]
                ),
                QuizItem(
                    question:
                        "In Baseball, how many times does the ball have to be pitched outside of the strike zone before the batter is walked?",
                    correct: "4",
                    answers: [
                        "1", "2", "3", "4"
                    ]
                )
            ]
        }

        // HISTORY: 2 Easy True/False
        if category == 23
            && amount == 2
            && difficulty == "easy"
            && questionType == "boolean" {

            return [
                QuizItem(
                    question:
                        "The majority of people that lived under the Byzantine Empire called themselves Romans.",
                    correct: "True",
                    answers: ["True", "False"]
                ),
                QuizItem(
                    question:
                        "The United States was a member of the League of Nations.",
                    correct: "False",
                    answers: ["True", "False"]
                )
            ]
        }

        // SCIENCE & NATURE: 10 Medium True/False
        if category == 17
            && amount == 10
            && difficulty == "medium"
            && questionType == "boolean" {

            let rows: [(String, String)] = [
                (
                    "Male pandas do handstands while urinating on trees. ",
                    "True"
                ),
                (
                    "The planet Mars has two moons orbiting it.",
                    "True"
                ),
                (
                    "Polaris is the brightest star in the northern hemisphere night sky.",
                    "False"
                ),
                (
                    "\"Tachycardia\" or \"Tachyarrhythmia\" refers to a resting heart-rate near or over 100 BPM.",
                    "True"
                ),
                (
                    "A person can get sunburned on a cloudy day.",
                    "True"
                ),
                (
                    "The Neanderthals were a direct ancestor of modern humans.",
                    "False"
                ),
                (
                    "In the periodic table, Potassium's symbol is the letter K.",
                    "True"
                ),
                (
                    "Type 1 diabetes is a result of the liver working improperly.",
                    "False"
                ),
                (
                    "The French scientists Louis Pasteur and Émile Roux developed the first rabies vaccination in 1885.",
                    "True"
                ),
                (
                    "Hippopotomonstrosesquippedaliophobia is the irrational fear of long words.",
                    "True"
                )
            ]

            return rows.map {
                QuizItem(
                    question: $0.0,
                    correct: $0.1,
                    answers: ["True", "False"]
                )
            }
        }

        return nil
    }

    private func decodeHTML(
        _ text: String
    ) -> String {
        let replacements = [
            "&quot;": "\"",
            "&#039;": "'",
            "&apos;": "'",
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&eacute;": "é",
            "&uuml;": "ü",
            "&rsquo;": "’",
            "&ldquo;": "“",
            "&rdquo;": "”"
        ]

        return replacements.reduce(text) {
            result, pair in
            result.replacingOccurrences(
                of: pair.key,
                with: pair.value
            )
        }
    }
}

