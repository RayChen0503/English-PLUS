package tw.edu.citizenaction.soracompanion.data

import tw.edu.citizenaction.soracompanion.auth.AuthContract
import tw.edu.citizenaction.soracompanion.model.AiScenario
import tw.edu.citizenaction.soracompanion.model.Breakpoint
import tw.edu.citizenaction.soracompanion.model.DesignPrinciple
import tw.edu.citizenaction.soracompanion.model.HandoffPriority
import tw.edu.citizenaction.soracompanion.model.HelpRequestOption
import tw.edu.citizenaction.soracompanion.model.InterventionStep
import tw.edu.citizenaction.soracompanion.model.JourneyStep
import tw.edu.citizenaction.soracompanion.model.LearningContract
import tw.edu.citizenaction.soracompanion.model.LearningModule
import tw.edu.citizenaction.soracompanion.model.LocalAccount
import tw.edu.citizenaction.soracompanion.model.MentorCheck
import tw.edu.citizenaction.soracompanion.model.MistakeRecord
import tw.edu.citizenaction.soracompanion.model.OfflinePack
import tw.edu.citizenaction.soracompanion.model.Question
import tw.edu.citizenaction.soracompanion.model.QuestionBankItem
import tw.edu.citizenaction.soracompanion.model.ReflectionPrompt
import tw.edu.citizenaction.soracompanion.model.StudentProfile
import tw.edu.citizenaction.soracompanion.model.StudentRow
import tw.edu.citizenaction.soracompanion.model.StudyTask
import tw.edu.citizenaction.soracompanion.model.SupportMessage
import tw.edu.citizenaction.soracompanion.model.SyncRecord
import tw.edu.citizenaction.soracompanion.model.TeacherAction
import tw.edu.citizenaction.soracompanion.model.UserFlowContract
import tw.edu.citizenaction.soracompanion.model.WeeklySignal

object PrototypeRepository {
    val student = StudentProfile(
        name = "小安",
        age = 14,
        location = "宜蘭縣誠致國中",
        grade = "八年級",
        goal = "把會考英文從 C 往 B 推進",
        constraint = "家裡網路不穩，晚上只有零碎時間可以練習。",
        mentor = "Emily 志工",
        learningStyle = "需要短題、明確提示和可重試的節奏。",
        supportNeed = "遇到閱讀長文或連續錯題時容易想放棄，需要先被接住。"
    )

    val modules = listOf(
        LearningModule("be 動詞修復", "am / is / are 主詞搭配", 68, "完成 2 題 be 動詞暖身", "進行中"),
        LearningModule("文法填空", "連接詞、介系詞與動詞型態", 54, "完成一組 4 題填空", "可挑戰"),
        LearningModule("閱讀理解", "短文主旨、細節與推論", 47, "先做一題短文主旨", "進行中"),
        LearningModule("翻譯/句子重組", "中文語意轉成英文句型", 39, "做一題句子重組", "需要陪伴"),
        LearningModule("復原任務", "狀態低落時的一題修復", 22, "完成 3 分鐘低壓任務", "低壓")
    )

    val questions = buildQuestions()
    val questionBankItems = buildQuestionBankItems(questions)

    private fun buildQuestions(): List<Question> {
        val items = mutableListOf<Question>()
        items += baseQuestions()
        items += buildChoiceExpansion()
        items += buildFillBlankExpansion()
        items += buildClozeExpansion()
        items += buildReadingExpansion()
        items += buildTranslationExpansion()
        return items.distinctBy { it.prompt }
    }

    private fun baseQuestions(): List<Question> = listOf(
        Question(
            "He ___ a student.",
            listOf("am", "is", "are", "be"),
            "is",
            "He 是第三人稱單數，be 動詞要用 is。",
            "be 動詞：He/She/It + is",
            UserFlowContract.TYPE_CHOICE,
            "先看主詞 He，再選 is。"
        ),
        Question(
            "They ___ my friends.",
            listOf("is", "are", "am", "be"),
            "are",
            "They 是複數主詞，be 動詞要用 are。",
            "be 動詞：複數主詞 + are",
            UserFlowContract.TYPE_CHOICE,
            "They 不是單數，所以不用 is。"
        ),
        Question(
            "If it ___ tomorrow, we will stay home.",
            listOf("rains", "will rain", "rained", "is raining"),
            "rains",
            "if 條件句的未來意思，if 子句用現在式。",
            "if 條件句",
            UserFlowContract.TYPE_FILL_BLANK,
            "看到 if + tomorrow，先想 if 子句不用 will。"
        ),
        Question(
            "Ms. Lin asked us ___ our reports before Friday.",
            listOf("to finish", "finish", "finished", "finishing"),
            "to finish",
            "ask + 人 + to V 表示請某人做某事。",
            "不定詞：ask someone to V",
            UserFlowContract.TYPE_FILL_BLANK,
            "看到 asked us，後面通常接 to V。"
        ),
        Question(
            "短文克漏字：Mia wanted to join the race, ___ she hurt her foot the day before it.",
            listOf("but", "so", "or", "because"),
            "but",
            "前後語意轉折：想參加比賽，但前一天受傷。",
            "轉折連接詞",
            UserFlowContract.TYPE_CLOZE,
            "先判斷前後句關係，是轉折就選 but。"
        ),
        Question(
            "閱讀理解：A sign says, 'Please return books on time. If a book is late, you cannot borrow another one until it is returned.' What happens if a student returns a book late?",
            listOf("The student must wait before borrowing again.", "The student can keep all books longer.", "The library gives a free book.", "The library closes for one day."),
            "The student must wait before borrowing again.",
            "題目問 late 的結果，原文說歸還前不能再借下一本。",
            "閱讀細節定位",
            UserFlowContract.TYPE_READING,
            "找 if a book is late 後面的限制。"
        ),
        Question(
            "翻譯/句子重組：我每天放學後練習英文。",
            listOf("I practice English after school every day.", "I after school every day practice English.", "Every day English practice I after school.", "I am practice English after school every day."),
            "I practice English after school every day.",
            "英文基本語序是主詞 + 動詞 + 受詞 + 時間。",
            "句子語序",
            UserFlowContract.TYPE_TRANSLATION,
            "先排 I practice English，再放 after school every day。"
        )
    )

    private fun buildChoiceExpansion(): List<Question> {
        val subjects = listOf(
            "My sister" to "is",
            "The students" to "are",
            "A good breakfast" to "is",
            "Those books" to "are",
            "Mr. Chen" to "is",
            "The cats" to "are",
            "English" to "is",
            "My parents" to "are",
            "This question" to "is",
            "The boys" to "are",
            "Our classroom" to "is",
            "Two tickets" to "are",
            "The movie" to "is",
            "Some apples" to "are",
            "The bus stop" to "is",
            "My shoes" to "are",
            "Her idea" to "is",
            "Many people" to "are",
            "The answer" to "is",
            "These stories" to "are",
            "A pair of glasses" to "is",
            "The lessons" to "are",
            "My homework" to "is",
            "Three questions" to "are",
            "The weather" to "is",
            "The players" to "are",
            "This sentence" to "is",
            "The houses" to "are",
            "Your plan" to "is",
            "The maps" to "are"
        )
        val scenes = listOf("important", "ready", "popular", "useful", "near the park", "easy to find", "on the desk", "helpful")
        return buildList {
            repeat(8) { round ->
                subjects.forEachIndexed { index, (subject, answer) ->
                    val scene = scenes[(round + index) % scenes.size]
                    add(
                        Question(
                            "選擇題 ${round + 1}-${index + 1}: $subject ___ $scene.",
                            listOf("am", "is", "are", "be"),
                            answer,
                            "$subject 的單複數決定 be 動詞，這裡要選 $answer。",
                            "be 動詞主詞搭配",
                            UserFlowContract.TYPE_CHOICE,
                            "先圈主詞，再判斷單數或複數。"
                        )
                    )
                }
            }
        }
    }

    private fun buildFillBlankExpansion(): List<Question> {
        val grammarItems = listOf(
            Triple("Tom has lived here ___ 2020.", "since", "since 接時間起點。"),
            Triple("The cake was made ___ my aunt.", "by", "被動語態中 by 表示動作者。"),
            Triple("I enjoy ___ English songs after class.", "listening to", "enjoy 後面接 V-ing。"),
            Triple("The movie was so boring that I almost fell ___.", "asleep", "fall asleep 表示睡著。"),
            Triple("Please turn ___ the lights before you leave.", "off", "turn off 表示關掉。"),
            Triple("Neither Leo nor his brothers ___ at home now.", "are", "nor 後面靠近的主詞 brothers 是複數。"),
            Triple("The woman ___ is talking to our teacher is my mom.", "who", "修飾人要用 who。"),
            Triple("I was doing homework when the phone ___.", "rang", "when 後面是過去發生的動作。"),
            Triple("The box is too heavy for me ___ carry.", "to", "too...to 表示太...而不能。"),
            Triple("We should save water ___ it is important.", "because", "because 用來說明原因。"),
            Triple("This restaurant is famous ___ its beef noodles.", "for", "be famous for 表示以...聞名。"),
            Triple("I have never ___ such an exciting game.", "seen", "have never 後接過去分詞。"),
            Triple("The train had left ___ we arrived.", "before", "before 表示在...之前。"),
            Triple("It is kind ___ you to help the new student.", "of", "It is kind of you 是固定用法。"),
            Triple("How long does it take ___ to school?", "to get", "It takes time to V。"),
            Triple("The teacher told us not ___ loudly in the library.", "to talk", "tell someone not to V。"),
            Triple("The more you practice, the ___ you will become.", "better", "the 比較級, the 比較級。"),
            Triple("I don't know ___ he will come or not.", "whether", "whether...or not 表示是否。"),
            Triple("The man speaks slowly so that everyone can ___ him.", "understand", "can 後面接原形動詞。"),
            Triple("The room needs ___ before the guests arrive.", "cleaning", "need V-ing 可表示需要被處理。"),
            Triple("If you heat ice, it ___ water.", "becomes", "事實條件句用現在式。"),
            Triple("I am interested ___ learning languages.", "in", "be interested in 是固定片語。"),
            Triple("She is looking forward ___ the trip.", "to", "look forward to 後面接名詞或 V-ing。"),
            Triple("The book is worth ___.", "reading", "be worth V-ing。"),
            Triple("He is good ___ solving problems.", "at", "be good at 表示擅長。")
        )
        return buildList {
            repeat(16) { round ->
                grammarItems.forEachIndexed { index, item ->
                    add(
                        Question(
                            "填空題 ${round + 1}-${index + 1}: ${item.first}",
                            distractorsFor(item.second),
                            item.second,
                            item.third,
                            "文法填空 ${index + 1}",
                            UserFlowContract.TYPE_FILL_BLANK,
                            "先看空格前後的固定搭配，再排除不合語法的選項。"
                        )
                    )
                }
            }
        }
    }

    private fun buildClozeExpansion(): List<Question> {
        val clozeItems = listOf(
            Pair("A school started a book corner in every classroom. Students can take a book during break time. This plan helps students read more ___ they do not have much free time.", listOf("even if", "before", "until", "unless")),
            Pair("Nina lost her student card on the way home. The next morning, a classmate returned it to her. Nina felt ___ and thanked him.", listOf("thankful", "hungry", "careless", "late")),
            Pair("Many people bring their own bags when they shop. This small habit can reduce waste and ___ the earth.", listOf("protect", "borrow", "forget", "invite")),
            Pair("Jason wrote down what he spent every day. After two months, he knew where his money ___.", listOf("went", "slept", "grew", "opened")),
            Pair("The soccer team did not win the first game. However, the players kept practicing and played much ___ in the final game.", listOf("better", "earlier", "louder", "heavier")),
            Pair("A museum guide told visitors not to touch the old paintings because oil from hands may ___ them.", listOf("damage", "follow", "enter", "answer")),
            Pair("Lily was nervous before her speech. Her teacher told her to breathe slowly, and the advice helped her feel more ___.", listOf("confident", "dangerous", "expensive", "crowded")),
            Pair("The new bus app shows arrival times, so students can wait at home ___ standing in the rain.", listOf("instead of", "because of", "as soon as", "even though")),
            Pair("Ben forgot his lunch, ___ his friend shared a sandwich with him.", listOf("so", "but", "or", "although")),
            Pair("The class cleaned the beach and found many plastic bottles. They learned that small actions can make a big ___.", listOf("difference", "mistake", "noise", "ticket")),
            Pair("Amy checked the map before leaving. She arrived on time because she knew the right ___.", listOf("route", "price", "song", "color")),
            Pair("The teacher gave fewer homework questions today so students could focus on doing them ___.", listOf("carefully", "loudly", "cheaply", "hungrily"))
        )
        return buildList {
            repeat(16) { round ->
                clozeItems.forEachIndexed { index, item ->
                    add(
                        Question(
                            "克漏字 ${round + 1}-${index + 1}: ${item.first}",
                            item.second,
                            item.second.first(),
                            "先讀上下文，選出最符合語意的字或片語：${item.second.first()}。",
                            "文意克漏字 ${index + 1}",
                            UserFlowContract.TYPE_CLOZE,
                            "不要只看空格，先抓前後句的因果、轉折或目的。"
                        )
                    )
                }
            }
        }
    }

    private fun buildReadingExpansion(): List<Question> {
        val readingItems = listOf(
            Triple("A poster says: Join the river clean-up this Saturday. Meet at the park gate at 8:30 a.m. Gloves and bags will be provided.", "What should people do first?", "Go to the park gate in the morning."),
            Triple("A message says: Dad, I left my science notebook on the kitchen table. Could you bring it to school before lunch?", "What does the writer need?", "A notebook from home."),
            Triple("A notice says: The school concert will move from the playground to the gym because of rain.", "Why was the place changed?", "Because the weather is rainy."),
            Triple("A short article says: Some students study better with quiet music, but songs with words may make reading harder.", "What is the main idea?", "Music can affect studying in different ways."),
            Triple("A timetable says: Bus 12 leaves every 20 minutes from 7:00 to 9:00 in the morning.", "If a bus leaves at 7:20, when is the next one?", "At 7:40."),
            Triple("A shop note says: Buy two sandwiches and get one drink for free before 11 a.m.", "When can customers get a free drink?", "Before 11 a.m."),
            Triple("An email says: Please send your group report by Friday night. Late reports will not be accepted.", "What must students do?", "Send the report by Friday night."),
            Triple("A weather report says: It will be cloudy in the morning, but heavy rain is expected after 3 p.m.", "When should people carry an umbrella?", "In the afternoon."),
            Triple("A library note says: Students may borrow three books at a time and keep them for two weeks.", "How many books can a student borrow at a time?", "Three books."),
            Triple("A club message says: Please bring a water bottle and wear comfortable shoes for the hiking activity.", "What should students prepare?", "A water bottle and comfortable shoes."),
            Triple("A short article says: Turning off notifications at night can help students sleep better.", "What is the article mainly about?", "A way to sleep better."),
            Triple("A class note says: The English quiz will have ten vocabulary questions and one reading passage.", "What will be on the quiz?", "Vocabulary questions and a reading passage.")
        )
        return buildList {
            repeat(16) { round ->
                readingItems.forEachIndexed { index, item ->
                    add(
                        Question(
                            "閱讀理解 ${round + 1}-${index + 1}: ${item.first}\n${item.second}",
                            listOf(item.third, "Wait until next week.", "Ask for a new phone.", "Close the school library."),
                            item.third,
                            "題目答案可以在短文中的關鍵句找到：${item.third}",
                            "閱讀理解 ${index + 1}",
                            UserFlowContract.TYPE_READING,
                            "先找題目問的關鍵字，再回原文定位。"
                        )
                    )
                }
            }
        }
    }

    private fun buildTranslationExpansion(): List<Question> {
        val translationItems = listOf(
            "我每天放學後練習英文。" to "I practice English after school every day.",
            "這本書對我來說太難懂了。" to "This book is too difficult for me to understand.",
            "如果明天下雨，我們會待在家。" to "If it rains tomorrow, we will stay home.",
            "我想知道公車什麼時候會到。" to "I want to know when the bus will arrive.",
            "我昨晚九點正在讀英文。" to "I was reading English at nine last night.",
            "這個問題比我想的更難。" to "This question is harder than I thought.",
            "你可以告訴我車站在哪裡嗎？" to "Can you tell me where the station is?",
            "他太累了，無法完成作業。" to "He was too tired to finish his homework.",
            "這是我讀過最有趣的故事。" to "This is the most interesting story I have ever read.",
            "如果你需要幫忙，請告訴我。" to "If you need help, please tell me.",
            "我們花了兩個小時完成海報。" to "It took us two hours to finish the poster.",
            "她不但會唱歌，也會彈吉他。" to "She can not only sing but also play the guitar.",
            "我不知道明天是否會下雨。" to "I don't know whether it will rain tomorrow.",
            "這張照片讓我想起我的家鄉。" to "This picture reminds me of my hometown.",
            "他今天早起，為了準時到校。" to "He got up early today to get to school on time.",
            "離開教室前請關燈。" to "Please turn off the lights before leaving the classroom.",
            "這部電影值得再看一次。" to "This movie is worth watching again.",
            "老師要我們分組討論這個故事。" to "The teacher asked us to discuss the story in groups.",
            "雖然天氣很熱，他仍然去練棒球。" to "Even though it was hot, he still went to practice baseball.",
            "我正在找一個可以安靜讀書的地方。" to "I am looking for a place where I can study quietly."
        )
        return buildList {
            repeat(15) { round ->
                translationItems.forEachIndexed { index, item ->
                    add(
                        Question(
                            "翻譯/句子重組 ${round + 1}-${index + 1}: ${item.first}",
                            listOf(
                                item.second,
                                item.second.replace("I ", "Me "),
                                item.second.replace(" is ", " are "),
                                item.second.replace(" to ", " for ")
                            ).distinct(),
                            item.second,
                            "先抓主詞和動詞，再把時間、地點或原因放到句尾。",
                            "句子重組 ${index + 1}",
                            UserFlowContract.TYPE_TRANSLATION,
                            "先排出完整主詞 + 動詞，再檢查時態。"
                        )
                    )
                }
            }
        }
    }

    private fun distractorsFor(answer: String): List<String> {
        val generic = listOf(answer, "to $answer", "${answer}ed", "${answer}ing", "will $answer")
        return generic.distinct().take(4).let { options ->
            if (options.size >= 2) options else listOf(answer, "is", "are", "to")
        }
    }

    private fun buildQuestionBankItems(sourceQuestions: List<Question>): List<QuestionBankItem> {
        return sourceQuestions.mapIndexed { index, question ->
            val typeIndex = sourceQuestions.take(index + 1).count { it.type == question.type }
            QuestionBankItem(
                id = "cap-style-${(index + 1).toString().padStart(4, '0')}",
                level = levelFor(question.type, typeIndex),
                unit = unitFor(question.type),
                skill = skillFor(question.type),
                source = if (index < 80) "English+ seed" else "English+ CAP-style original",
                question = question,
                reviewState = if (index < 120) "approved" else "draft"
            )
        }
    }

    private fun levelFor(type: String, typeIndex: Int): String {
        return when (type) {
            UserFlowContract.TYPE_CHOICE -> when {
                typeIndex <= 80 -> "A1"
                typeIndex <= 180 -> "A2"
                typeIndex <= 230 -> "B1"
                else -> "B2"
            }
            UserFlowContract.TYPE_FILL_BLANK -> when {
                typeIndex <= 60 -> "A2"
                typeIndex <= 180 -> "B1"
                else -> "B2"
            }
            UserFlowContract.TYPE_CLOZE -> if (typeIndex <= 50) "A2" else if (typeIndex <= 100) "B1" else "B2"
            UserFlowContract.TYPE_READING -> if (typeIndex <= 50) "A2" else if (typeIndex <= 100) "B1" else "B2"
            UserFlowContract.TYPE_TRANSLATION -> if (typeIndex <= 40) "A2" else if (typeIndex <= 180) "B1" else "B2"
            else -> "A2"
        }
    }

    private fun unitFor(type: String): String {
        return when (type) {
            UserFlowContract.TYPE_FILL_BLANK -> "文法填空"
            UserFlowContract.TYPE_CLOZE -> "短文克漏字"
            UserFlowContract.TYPE_READING -> "短文閱讀"
            UserFlowContract.TYPE_TRANSLATION -> "句子重組"
            else -> "基礎文法"
        }
    }

    private fun skillFor(type: String): String {
        return when (type) {
            UserFlowContract.TYPE_FILL_BLANK -> "文法判斷"
            UserFlowContract.TYPE_CLOZE -> "文意判斷"
            UserFlowContract.TYPE_READING -> "閱讀定位"
            UserFlowContract.TYPE_TRANSLATION -> "句型轉換"
            else -> "主詞搭配"
        }
    }

    fun initialBreakpoints(): MutableList<Breakpoint> = mutableListOf(
        Breakpoint("be 動詞反覆錯", "高", "He am / He are 連續錯 3 次。", "English+ 先拆成 He is / They are 兩個規則。", "志工陪學生口說 3 組 He is / She is。"),
        Breakpoint("閱讀長文停住", "中", "閱讀題停留 18 秒以上沒有選項。", "先改成找關鍵句，再回到題目。", "老師可示範如何圈關鍵字。")
    )

    val roster = listOf(
        StudentRow("小安", "高", "be 動詞與填空反覆錯", "需要老師回覆 1 則"),
        StudentRow("阿翔", "中", "閱讀題抓不到主旨", "等待志工陪練"),
        StudentRow("小婷", "低", "心情低落但願意做短題", "保留低壓任務"),
        StudentRow("小宇", "中", "翻譯句序不穩", "需要句型提示"),
        StudentRow("佳穎", "低", "閱讀細節題進步中", "可挑戰 B1")
    )

    val studyTasks = listOf(
        StudyTask("He is / She is 快速判斷", 3, "低", "先用一題建立成功感。", "今日可做"),
        StudyTask("文法填空 3 題", 5, "中", "練 if 條件句、to V 與連接詞。", "排程中"),
        StudyTask("短文克漏字練習", 6, "中", "練語意轉折與因果判斷。", "可挑戰"),
        StudyTask("閱讀理解主旨題", 8, "高", "適合完成今日任務後挑戰。", "進階")
    )

    val supportMessages = listOf(
        SupportMessage("English+ 回饋", "剛剛", "你不是不會英文，是這題卡在主詞搭配。先看 He，再選 is。", "低壓"),
        SupportMessage("Emily 志工", "20:12", "小安，你願意回來重試很好。我們今天只練 He is / She is。", "鼓勵"),
        SupportMessage("老師", "今天", "我看見你在閱讀題有停住，下一次先圈題目問什麼。", "具體")
    )

    val weeklySignals = listOf(
        WeeklySignal("完成短任務", "4 次", "比上週多 1 次", "#0F766E"),
        WeeklySignal("文法修復", "5 題", "集中在 be 動詞與 if 條件句", "#246BFD"),
        WeeklySignal("求助訊號", "1 次", "已由志工接力", "#B45309"),
        WeeklySignal("未完成任務", "1 次", "需要降低題目長度", "#B91C1C")
    )

    val mistakeRecords = listOf(
        MistakeRecord("He / She / It + is", "把 He 接成 am 或 are", "先練 He is / She is 兩題", "已修復 1 題"),
        MistakeRecord("if 條件句", "if 子句誤用 will rain", "記住 if + 現在式，主句才用 will", "練習中"),
        MistakeRecord("克漏字轉折", "看到 because 就想選 so", "先判斷前後句是原因、結果或轉折", "需要陪練")
    )

    val offlinePacks = listOf(
        OfflinePack("3 分鐘 be 動詞修復", "1.2 MB", "3-5 分鐘", "5 題選擇題與即時提示。"),
        OfflinePack("文法填空小包", "1.4 MB", "5-8 分鐘", "if 條件句、to V、連接詞。"),
        OfflinePack("閱讀理解短包", "1.8 MB", "8-10 分鐘", "短文主旨與細節定位。")
    )

    val mentorChecks = listOf(
        MentorCheck("低壓任務是否可完成", "完成", "學生完成一題後願意再重試。", "#0F766E"),
        MentorCheck("錯題是否有被拆小", "完成", "錯題已轉成一個規則提示。", "#0F766E"),
        MentorCheck("是否需要真人陪伴", "觀察", "如果再連錯兩次，交給志工陪練。", "#B45309"),
        MentorCheck("任務長度是否合理", "完成", "今天維持 3-5 分鐘。", "#0F766E"),
        MentorCheck("接力紀錄是否清楚", "待補", "回覆後要寫下下一步。", "#B45309")
    )

    val handoffPriorities = listOf(
        HandoffPriority("小安 if 條件句卡住", "Emily 志工", "陪學生看 if it rains / we will stay home", "高"),
        HandoffPriority("阿翔閱讀主旨題停住", "老師", "示範圈題目關鍵字", "中"),
        HandoffPriority("小婷心情低落", "English+ 回饋", "安排 3 分鐘復原任務", "低")
    )

    val journeySteps = listOf(
        JourneyStep("打開 App", "擔心又要被考試", "先問今天狀態與時間", "還不進題庫"),
        JourneyStep("完成檢測", "知道今天只要做幾題", "產生一個清楚任務", "依心情和時間縮小任務"),
        JourneyStep("做題卡住", "怕自己又錯", "先給提示再重試", "多次卡住才接力"),
        JourneyStep("需要陪伴", "想有人看見自己卡住", "整理給老師或志工", "高風險才交給真人"),
        JourneyStep("完成任務", "有完成感", "出現達標提示與自由練習", "不再強迫加題")
    )

    val interventionSteps = listOf(
        InterventionStep("心情偏低", "改成 3 分鐘復原任務", "今天只要完成一小題。", "心情量表 1-2"),
        InterventionStep("錯題連續發生", "把題目拆成一個規則", "先看這個提示，再試一次。", "同概念錯兩次"),
        InterventionStep("仍然卡住", "整理求助訊息", "English+ 會把題目和你的狀態整理好。", "重試仍錯"),
        InterventionStep("真人接力", "老師或志工回覆", "你可以看到對方給你的下一步。", "高風險或學生主動求助")
    )

    val designPrinciples = listOf(
        DesignPrinciple("先接住狀態", "學生先看到今天能做什麼，不先看到一堆功能。", "首頁先做角色分流與心情檢測。"),
        DesignPrinciple("進度只算題目", "今日任務進度只看答對的指定題。", "自由練習不會改變進度條。"),
        DesignPrinciple("AI 不取代真人", "AI 先拆題與整理語氣，需要時才交給老師或志工。", "支持系統有清楚接力出口。"),
        DesignPrinciple("角色不混雜", "學生、老師、志工看到不同任務。", "底部導航依角色分開。")
    )

    val helpRequestOptions = listOf(
        HelpRequestOption("我看不懂這題", "我不知道這題在問什麼。", "English+ 先把題目拆成一句話。", "AI 陪伴"),
        HelpRequestOption("我想要有人陪我", "我知道答案好像不對，但不知道差在哪裡。", "系統會整理給老師或志工。", "志工接力"),
        HelpRequestOption("閱讀題太長", "我看到閱讀題就停住。", "先抓題目關鍵字，再回原文找句子。", "閱讀拆解"),
        HelpRequestOption("今天狀態不好", "我想先做很小的任務。", "切換成復原任務。", "復原任務")
    )

    val learningContracts = listOf(
        LearningContract("今天只做一小步", "我先完成 3-5 分鐘任務。", "English+ 不把錯題當懲罰。", "老師/志工只給下一步，不加壓。"),
        LearningContract("錯題可以重試", "我可以先看提示再回來。", "English+ 會保留我的進度。", "陪伴者先肯定再提示。"),
        LearningContract("需要幫忙可以說", "我可以把卡住的地方交出去。", "English+ 會整理題目和狀態。", "老師或志工回覆具體下一步。")
    )

    val reflectionPrompts = listOf(
        ReflectionPrompt("今天完成哪一小步？", "我完成了一題。", "這已經算完成今日任務。", 3),
        ReflectionPrompt("哪個地方還卡住？", "我還不懂 if 條件句。", "下次先練 if + 現在式。", 1),
        ReflectionPrompt("要不要請人接力？", "我想要老師看一下。", "系統會整理給老師。", 0)
    )

    val teacherActions = listOf(
        TeacherAction("回覆小安 if 條件句", "Emily 志工", "待回覆", "今晚 21:00", "if 子句誤用 will rain", "給一組 if it rains / we will stay home。"),
        TeacherAction("追蹤阿翔閱讀主旨題", "老師", "待處理", "明天", "閱讀題停留過久", "示範先讀題再找關鍵句。"),
        TeacherAction("新增低壓文法任務", "老師", "已完成", "剛剛", "學生晚上時間不足", "加入 3 分鐘任務包。")
    )

    val syncRecords = listOf(
        SyncRecord("學習紀錄已保存", "完成", "已記錄 1 題 be 動詞練習。"),
        SyncRecord("接力回覆已更新", "處理中", "老師回覆將出現在學生支持頁。"),
        SyncRecord("任務包已準備", "完成", "可在網路不穩時練習。")
    )

    val localAccounts = listOf(
        LocalAccount("小安", AuthContract.ROLE_STUDENT, "YILAN-CHENGZHI-8A", "學生帳號"),
        LocalAccount("Emily", AuthContract.ROLE_VOLUNTEER, "MENTOR-GROUP-A", "志工帳號"),
        LocalAccount("林老師", AuthContract.ROLE_TEACHER, "CLASS-ENGLISH-02", "老師帳號")
    )

    val aiScenarios = listOf(
        AiScenario(
            "文法填空修復",
            "學生選 If it will rain tomorrow...",
            "卡在 if 條件句時態。",
            "if 子句用現在式：If it rains tomorrow, we will stay home.",
            "學生需要一組 if it rains / we will stay home 的口說練習。"
        ),
        AiScenario(
            "閱讀主旨拆解",
            "學生看到短文後停住。",
            "可能不知道題目要找主旨還是細節。",
            "先看題目問 main idea 或 detail，再回原文定位。",
            "建議老師示範圈題目關鍵字。"
        ),
        AiScenario(
            "翻譯句序提示",
            "學生把時間放在主詞前。",
            "卡在英文基本語序。",
            "先排主詞 + 動詞 + 受詞，再放時間。",
            "志工可陪學生重組兩個短句。"
        )
    )
}
