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
import tw.edu.citizenaction.soracompanion.model.WeeklySignal

object PrototypeRepository {
    val student = StudentProfile(
        name = "小安",
        age = 14,
        location = "宜蘭偏鄉",
        grade = "八年級",
        goal = "英文從 C 慢慢拉回 B",
        constraint = "家裡網路不穩，完整測驗容易焦慮",
        mentor = "志工 Emily",
        learningStyle = "需要短任務、明確提示和可被接住的錯誤回饋",
        supportNeed = "先降低挫折，再把真正需要人的地方交給老師或志工"
    )

    val modules = listOf(
        LearningModule("be 動詞暖身", "am / is / are 的基本判斷", 68, "再練 2 題主詞搭配", "進行中"),
        LearningModule("會考克漏字", "用上下文判斷語意與文法", 54, "完成一篇 4 題短文", "可挑戰"),
        LearningModule("閱讀理解", "從公告、訊息、短文找線索", 47, "先練主旨與細節題", "進行中"),
        LearningModule("翻譯/句子重組", "把中文意思轉成自然英文", 39, "先掌握主詞、動詞、時間", "待修復"),
        LearningModule("錯題復原", "把常錯規則整理成下一步", 22, "只做一個 3 分鐘修復任務", "低壓")
    )

    val questions = buildQuestions()
    val questionBankItems = buildQuestionBankItems(questions)

    private fun buildQuestions(): List<Question> {
        return listOf(
            Question("He ___ a student.", listOf("am", "is", "are"), "is", "He 是第三人稱單數，要搭配 is。", "be 動詞：He/She/It + is", "選擇題", "先看主詞 He，再選第三人稱單數的 is。"),
            Question("They ___ my friends.", listOf("is", "are", "am"), "are", "They 是複數主詞，要搭配 are。", "be 動詞：複數 + are", "選擇題", "They 表示很多人，先排除 is 和 am。"),
            Question("I ___ ready.", listOf("am", "is", "are"), "am", "I 固定搭配 am。", "be 動詞：I + am", "選擇題", "看到 I，先想 I am。"),
            Question("She ___ happy today.", listOf("are", "am", "is"), "is", "She 和 He 一樣，要搭配 is。", "be 動詞：She + is", "選擇題", "She 是一個人，第三人稱單數用 is。"),
            Question("We ___ in the classroom.", listOf("is", "are", "am"), "are", "We 是複數主詞，要搭配 are。", "be 動詞：We + are", "選擇題", "We 表示我們，通常搭配 are。"),
            Question("The boy is reading a book. 這句的主詞是？", listOf("The boy", "reading", "a book"), "The boy", "主詞是做動作的人，這裡是 The boy。", "閱讀：找主詞", "選擇題", "先問：誰正在 reading？答案是 The boy。"),
            Question("Thank you. 最自然的回應是？", listOf("You're welcome.", "Good night.", "I'm sorry."), "You're welcome.", "別人說謝謝時，可以回 You're welcome。", "口語：感謝回應", "選擇題", "看到 Thank you，就想 You're welcome。"),
            Question("usually 的意思比較接近？", listOf("通常", "從不", "明天"), "通常", "usually 表示通常、經常。", "單字：頻率副詞", "選擇題", "usually 是頻率字，表示事情常常發生。"),

            Question("If it ___ tomorrow, the baseball game will be canceled.", listOf("rains", "rained", "will rain", "is raining"), "rains", "if 條件句談未來時，if 子句通常用現在式。", "會考文法：條件句", "填空題", "看到 If + tomorrow，主句有 will，空格用現在式 rains。"),
            Question("Ms. Lin asked us ___ our reports before Friday.", listOf("finish", "to finish", "finished", "finishing"), "to finish", "ask + 人 + to V 表示要求某人做某事。", "會考文法：不定詞", "填空題", "先看 asked us，後面常接 to finish。"),
            Question("This is the camera ___ my uncle bought in Japan.", listOf("who", "where", "which", "when"), "which", "先行詞 camera 是物品，關係代名詞用 which。", "會考文法：關係代名詞", "填空題", "先判斷先行詞是人還是物，camera 是物。"),
            Question("The soup tastes too ___. Could I have some water?", listOf("salty", "quiet", "heavy", "early"), "salty", "需要水通常表示湯太鹹，salty 最符合語意。", "會考字彙：語意判斷", "填空題", "不要只看單字，後句 some water 是線索。"),

            Question("克漏字：A young man found a wallet on the bus. He did not keep it. He took it to the driver because he thought it was the ___ thing to do.", listOf("right", "cheap", "noisy", "empty"), "right", "撿到錢包交給司機是正確的事，right 表示正確的。", "會考克漏字：上下文語意", "克漏字", "前兩句說他沒有私留，後面應該是正確的事。"),
            Question("克漏字：Mia wanted to join the race, ___ she hurt her foot the day before it.", listOf("but", "so", "or", "because"), "but", "想參加比賽與腳受傷形成轉折，要用 but。", "會考克漏字：連接詞", "克漏字", "前後意思相反，找轉折連接詞。"),
            Question("克漏字：The notice says students should bring their own cups. This helps the school use ___ paper cups.", listOf("fewer", "much", "little", "more than"), "fewer", "cups 是可數複數，減少紙杯要用 fewer。", "會考克漏字：數量詞", "克漏字", "先看 paper cups 是可數複數。"),
            Question("克漏字：Kevin studied hard for the test. When he saw his score, he smiled because his work had finally ___.", listOf("paid off", "put on", "looked up", "turned down"), "paid off", "努力有成果可用 paid off。", "會考克漏字：片語", "克漏字", "hard work + score + smiled 表示努力有回報。"),

            Question("閱讀理解：A sign at a library says, 'Please return books on time. If a book is late, you cannot borrow another one until it is returned.' What happens if a student returns a book late?", listOf("The student must wait before borrowing again.", "The student can keep all books longer.", "The library will give a free book.", "The library closes for one day."), "The student must wait before borrowing again.", "公告說逾期未還前不能再借書。", "會考閱讀：公告細節", "閱讀理解", "先找 If a book is late 後面的規則。"),
            Question("閱讀理解：Tina texted Ben, 'I will be ten minutes late. Please order noodles for me first.' What does Tina want Ben to do?", listOf("Order food before she arrives.", "Cancel the meeting.", "Wait outside the station.", "Buy a train ticket."), "Order food before she arrives.", "她會晚到，請 Ben 先幫她點麵。", "會考閱讀：訊息理解", "閱讀理解", "text message 題先找請求動作。"),
            Question("閱讀理解：A short article says many students sleep with their phones near their beds. It suggests turning off notifications at night. What is the article mainly about?", listOf("A way to sleep better", "A history of phones", "A new school rule", "A popular game"), "A way to sleep better", "文章提到手機通知影響夜間睡眠，主旨是改善睡眠。", "會考閱讀：主旨", "閱讀理解", "主旨題要抓整段重複的核心：phone, night, sleep。"),
            Question("閱讀理解：The weather report says, 'It will be cloudy in the morning, but heavy rain is expected after 3 p.m.' When should people carry an umbrella?", listOf("In the afternoon", "Only at midnight", "Before sunrise", "Never"), "In the afternoon", "heavy rain is expected after 3 p.m. 表示下午需要傘。", "會考閱讀：時間線索", "閱讀理解", "抓 after 3 p.m.，不要被 morning 迷惑。"),

            Question("翻譯/句子重組：『我每天放學後練習英文。』最自然的英文是？", listOf("I practice English after school every day.", "I after school every day practice English.", "Every day English practice I after school.", "I am practice English after school every day."), "I practice English after school every day.", "英文基本順序是主詞 + 動詞 + 受詞 + 時間。", "會考翻譯：語序", "翻譯/句子重組", "先排 I practice English，再放 after school every day。"),
            Question("翻譯/句子重組：『這本書太難了，我看不懂。』最自然的英文是？", listOf("This book is too difficult for me to understand.", "This book too difficult I cannot understand it.", "I am too difficult to understand this book.", "This book is difficult too understand me."), "This book is too difficult for me to understand.", "too + 形容詞 + for 人 + to V 可表達太難而無法理解。", "會考翻譯：too...to", "翻譯/句子重組", "看到『太...而不能』，想 too difficult for me to understand。"),
            Question("翻譯/句子重組：『如果明天下雨，我們就待在家。』最自然的英文是？", listOf("If it rains tomorrow, we will stay home.", "If it will rain tomorrow, we stay home.", "Tomorrow rains if we will home stay.", "If tomorrow rain, we are stay home."), "If it rains tomorrow, we will stay home.", "if 條件句談未來，if 子句用現在式 rains，主句用 will。", "會考翻譯：條件句", "翻譯/句子重組", "if 子句不要用 will rain。"),
            Question("翻譯/句子重組：『我想知道公車什麼時候會到。』最自然的英文是？", listOf("I want to know when the bus will arrive.", "I want know when will the bus arrive.", "I want to know when will arrive the bus.", "I want knowing the bus when arrive."), "I want to know when the bus will arrive.", "間接問句用直述句語序：when the bus will arrive。", "會考翻譯：間接問句", "翻譯/句子重組", "間接問句不是 when will the bus arrive。")
        ) + buildExpandedCapStyleQuestions() + buildLargeCapStyleQuestionExpansion()
    }

    private fun buildExpandedCapStyleQuestions(): List<Question> {
        val questions = mutableListOf<Question>()

        val choiceSubjects = listOf(
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
            "Her idea" to "is"
        )
        choiceSubjects.forEachIndexed { index, (subject, answer) ->
            questions.add(
                Question(
                    "$subject ___ important in this sentence.",
                    listOf("am", "is", "are", "be"),
                    answer,
                    "$subject 的單複數決定 be 動詞，這題答案是 $answer。",
                    "be 動詞：主詞一致 ${index + 1}",
                    "選擇題",
                    "先判斷主詞是一個人/物，還是很多人/物。"
                )
            )
        }

        val fillItems = listOf(
            Triple("Tom has lived here ___ 2020.", "since", "since 接時間起點。"),
            Triple("The cake was made ___ my aunt.", "by", "被動語態中 by 表示動作者。"),
            Triple("I enjoy ___ English songs after class.", "listening to", "enjoy 後面接 V-ing。"),
            Triple("The movie was so boring that I almost fell ___.", "asleep", "fall asleep 表示睡著。"),
            Triple("Please turn ___ the lights before you leave.", "off", "turn off 表示關掉。"),
            Triple("Neither Leo nor his brothers ___ at home now.", "are", "nor 後面的主詞 brothers 決定動詞。"),
            Triple("The woman ___ is talking to our teacher is my mom.", "who", "先行詞是人，用 who。"),
            Triple("I was doing homework when the phone ___.", "rang", "when 引導過去事件，主句用過去進行。"),
            Triple("The box is too heavy for me ___ carry.", "to", "too...to 表示太...而無法。"),
            Triple("We should save water ___ it is important.", "because", "後句說原因，用 because。"),
            Triple("This restaurant is famous ___ its beef noodles.", "for", "be famous for 表示以...聞名。"),
            Triple("I have never ___ such an exciting game.", "seen", "完成式 have never 後接過去分詞。"),
            Triple("The train had left ___ we arrived.", "before", "先離開，再抵達，用 before。"),
            Triple("It is kind ___ you to help the new student.", "of", "It is kind of you 是固定用法。"),
            Triple("How long does it take ___ to school?", "to get", "It takes time to V。"),
            Triple("The teacher told us not ___ loudly in the library.", "to talk", "tell 人 not to V。"),
            Triple("The more you practice, the ___ you will become.", "better", "the 比較級, the 比較級。"),
            Triple("I don't know ___ he will come or not.", "whether", "whether...or not 表示是否。"),
            Triple("The man speaks slowly so that everyone can ___ him.", "understand", "can 後面接原形動詞。"),
            Triple("The room needs ___ before the guests arrive.", "cleaning", "need V-ing 可表示需要被做。"),
            Triple("If you heat ice, it ___ water.", "becomes", "零條件句表示自然結果，用現在式。")
        )
        fillItems.forEachIndexed { index, item ->
            questions.add(
                Question(
                    item.first,
                    listOf(item.second, "will " + item.second, item.second + "ed", "to " + item.second).distinct().take(4),
                    item.second,
                    item.third,
                    "會考填空：文法與語意 ${index + 1}",
                    "填空題",
                    "先判斷空格需要介系詞、動詞型態、連接詞，還是片語。"
                )
            )
        }

        val clozeContexts = listOf(
            "A school started a book corner in every classroom. Students can take a book during break time and return it after they finish reading. This plan helps students read more ___ they do not have much free time.",
            "Nina lost her student card on the way home. She wrote a message online and asked if anyone had seen it. The next morning, a classmate returned it to her. Nina felt ___ and thanked him.",
            "Many people bring their own bags when they shop. This small habit can reduce waste and make the city cleaner. It is an easy way to ___ the earth.",
            "Jason wanted to buy a new phone, but he decided to save money first. He wrote down what he spent every day. After two months, he knew where his money ___.",
            "The soccer team did not win the first game. However, the players kept practicing and learned from their mistakes. In the final game, they played much ___.",
            "A museum guide told visitors not to touch the old paintings. The rule is important because oil and dirt from hands may ___ the paintings.",
            "Lily was nervous before her speech. Her teacher told her to breathe slowly and look at one friendly face. The advice helped her feel more ___."
        )
        val clozeAnswers = listOf(
            listOf("even if", "before", "until", "unless"),
            listOf("thankful", "hungry", "careless", "late"),
            listOf("protect", "borrow", "forget", "invite"),
            listOf("went", "slept", "grew", "opened"),
            listOf("better", "earlier", "louder", "heavier"),
            listOf("damage", "follow", "enter", "answer"),
            listOf("confident", "dangerous", "expensive", "crowded")
        )
        repeat(3) { round ->
            clozeContexts.forEachIndexed { index, prompt ->
                val options = clozeAnswers[index]
                questions.add(
                    Question(
                        "克漏字：$prompt",
                        options,
                        options.first(),
                        "依照上下文，${options.first()} 最符合文章語意。",
                        "會考克漏字：上下文線索 ${round + 1}-${index + 1}",
                        "克漏字",
                        "先看空格前後句，判斷是原因、轉折、感受、動作或結果。"
                    )
                )
            }
        }

        val readingPrompts = listOf(
            Triple("A poster says: Join the river clean-up this Saturday. Meet at the park gate at 8:30 a.m. Gloves and bags will be provided.", "What should people do first?", "Go to the park gate in the morning."),
            Triple("A message says: Dad, I left my science notebook on the kitchen table. Could you bring it to school before lunch?", "What does the writer need?", "A notebook from home."),
            Triple("A notice says: The school concert will move from the playground to the gym because of rain.", "Why was the place changed?", "Because the weather is rainy."),
            Triple("A short article says: Some students study better with quiet music, but songs with words may make reading harder.", "What is the main idea?", "Music can affect studying in different ways."),
            Triple("A timetable says: Bus 12 leaves every 20 minutes from 7:00 to 9:00 in the morning.", "If a bus leaves at 7:20, when is the next one?", "At 7:40."),
            Triple("A shop note says: Buy two sandwiches and get one drink for free before 11 a.m.", "When can customers get a free drink?", "Before 11 a.m."),
            Triple("An email says: Please send your group report by Friday night. Late reports will not be accepted.", "What must students do?", "Send the report by Friday night.")
        )
        repeat(3) { round ->
            readingPrompts.forEachIndexed { index, item ->
                questions.add(
                    Question(
                        "閱讀理解：${item.first}\n${item.second}",
                        listOf(item.third, "Wait until next week.", "Ask for a new phone.", "Close the school library."),
                        item.third,
                        "題目線索在文字中可以直接找到或推論出來。",
                        "會考閱讀：生活文本 ${round + 1}-${index + 1}",
                        "閱讀理解",
                        "先看問題，再回到公告、訊息或短文找同義線索。"
                    )
                )
            }
        }

        val translationItems = listOf(
            "我昨天晚上九點正在讀英文。" to "I was reading English at nine last night.",
            "這個問題比我想的更難。" to "This question is harder than I thought.",
            "你能告訴我車站在哪裡嗎？" to "Can you tell me where the station is?",
            "他太累了，所以沒有完成作業。" to "He was too tired to finish his homework.",
            "這是我看過最有趣的故事。" to "This is the most interesting story I have ever read.",
            "如果你需要幫忙，請告訴我。" to "If you need help, please tell me.",
            "我們花了兩小時完成海報。" to "It took us two hours to finish the poster.",
            "她不但會唱歌，也會彈吉他。" to "She can not only sing but also play the guitar.",
            "我不知道明天是否會下雨。" to "I don't know whether it will rain tomorrow.",
            "這張照片讓我想起我的家鄉。" to "This picture reminds me of my hometown.",
            "為了準時到校，他今天很早起床。" to "He got up early today to get to school on time.",
            "請在離開教室前關燈。" to "Please turn off the lights before leaving the classroom.",
            "這部電影值得再看一次。" to "This movie is worth watching again.",
            "老師要我們分組討論這個故事。" to "The teacher asked us to discuss the story in groups.",
            "即使天氣很熱，他仍然去練球。" to "Even though it was hot, he still went to practice baseball.",
            "我正在找一個可以安靜讀書的地方。" to "I am looking for a place where I can study quietly."
        )
        translationItems.forEachIndexed { index, item ->
            questions.add(
                Question(
                    "翻譯/句子重組：『${item.first}』最自然的英文是？",
                    listOf(item.second, item.second.replace("I ", "Me "), item.second.replace(" is ", " are "), item.second.replace(" to ", " for ")).distinct().take(4),
                    item.second,
                    "注意英文語序、時態與固定搭配。",
                    "會考翻譯：語序與句型 ${index + 1}",
                    "翻譯/句子重組",
                    "先排主詞和動詞，再確認時間、連接詞與片語位置。"
                )
            )
        }

        return questions
    }

    private fun buildLargeCapStyleQuestionExpansion(): List<Question> {
        val questions = mutableListOf<Question>()

        val subjects = listOf(
            "My brother" to "is",
            "The girls" to "are",
            "A healthy lunch" to "is",
            "Those ideas" to "are",
            "The weather" to "is",
            "Two bikes" to "are",
            "Her answer" to "is",
            "Our neighbors" to "are",
            "This story" to "is",
            "Many students" to "are",
            "The train station" to "is",
            "These cookies" to "are",
            "A quiet room" to "is",
            "The players" to "are",
            "His plan" to "is",
            "My classmates" to "are"
        )
        val choiceScenes = listOf("important", "ready", "popular", "useful", "near the park", "easy to find")
        repeat(18) { round ->
            subjects.forEachIndexed { index, (subject, answer) ->
                val scene = choiceScenes[(round + index) % choiceScenes.size]
                questions.add(
                    Question(
                        "選擇題 ${round + 1}-${index + 1}: $subject ___ $scene.",
                        listOf(answer, "am", "is", "are").distinct(),
                        answer,
                        "先判斷主詞單複數，再選 be 動詞；$subject 要用 $answer。",
                        "主詞一致：be 動詞 ${round + 1}-${index + 1}",
                        "選擇題",
                        "先圈主詞，再判斷是一個還是很多。"
                    )
                )
            }
        }

        val grammarItems = listOf(
            Triple("Mia has studied English ___ three years.", "for", "for 接一段時間。"),
            Triple("The window was broken ___ a baseball.", "by", "被動語態用 by 表示動作者或原因。"),
            Triple("I am interested ___ learning new words.", "in", "be interested in 是固定搭配。"),
            Triple("Please give me something cold ___ drink.", "to", "something + 形容詞 + to V。"),
            Triple("The boy ___ won the race is my cousin.", "who", "先行詞是人，用 who。"),
            Triple("This is the book ___ I bought yesterday.", "which", "先行詞是物，用 which。"),
            Triple("If she ___ early, she will catch the bus.", "gets up", "if 條件句談未來，if 子句用現在式。"),
            Triple("The teacher asked us ___ our phones away.", "to put", "ask + 人 + to V。"),
            Triple("I was taking a shower when you ___.", "called", "過去進行搭配過去簡單式事件。"),
            Triple("This bag is not light enough for me ___ carry.", "to", "enough for 人 to V。"),
            Triple("We should leave now ___ we will be late.", "or", "or 可表示否則。"),
            Triple("The soup smells ___. I want to try it.", "good", "smell 後接形容詞。"),
            Triple("I have already ___ my homework.", "finished", "完成式 have + p.p.。"),
            Triple("The museum is closed, ___ we cannot go inside.", "so", "前句造成結果，用 so。"),
            Triple("She practices every day in order ___ win.", "to", "in order to V。"),
            Triple("Neither Jack nor I ___ ready.", "am", "neither...nor 看靠近動詞的主詞 I。"),
            Triple("The more you read, the ___ you understand.", "more", "the more..., the more... 表示越...越...。"),
            Triple("Could you tell me where the restroom ___?", "is", "間接問句用直述句語序。"),
            Triple("The baby stopped ___ when his mom came back.", "crying", "stop V-ing 表示停止正在做的事。"),
            Triple("This movie is worth ___.", "watching", "be worth V-ing。"),
            Triple("I don't know whether he ___ join us.", "will", "whether 後可接未來助動詞 will。"),
            Triple("The room needs ___ before dinner.", "cleaning", "need V-ing 表示需要被做。"),
            Triple("It took me thirty minutes ___ the report.", "to finish", "It takes time to V。"),
            Triple("Although it was raining, they ___ playing.", "kept", "although 表讓步，主句仍用 kept。")
        )
        repeat(11) { round ->
            grammarItems.forEachIndexed { index, item ->
                questions.add(
                    Question(
                        "填空題 ${round + 1}-${index + 1}: ${item.first}",
                        listOf(item.second, "will ${item.second}", "${item.second}ed", "to ${item.second}").distinct(),
                        item.second,
                        item.third,
                        "會考文法填空 ${round + 1}-${index + 1}",
                        "填空題",
                        "先看空格前後，判斷需要介系詞、連接詞、動詞型態或片語。"
                    )
                )
            }
        }

        val clozeItems = listOf(
            Triple("A class started a no-phone hour. Students put phones in a box and talked to friends. Many said they felt closer to their classmates ___ they were not checking messages.", "because", "前後是原因關係。"),
            Triple("Ken found a lost dog near school. He took a picture and posted it online. An hour later, the owner came and thanked him. Ken felt ___.", "helpful", "幫助別人後會覺得有幫助、有成就。"),
            Triple("Many families bring bottles when they travel. This habit helps them buy ___ plastic bottles.", "fewer", "bottles 是可數複數，減少用 fewer。"),
            Triple("Amy wanted to answer the question, ___ she was not sure about the grammar.", "but", "想回答和不確定形成轉折。"),
            Triple("The team lost the first game. However, they watched the video and practiced harder. Their work finally ___.", "paid off", "努力有成果用 paid off。"),
            Triple("A sign says visitors should speak quietly in the hospital. This rule helps patients rest ___.", "better", "安靜能讓病人休息得更好。"),
            Triple("Leo forgot his umbrella, so he waited at school ___ the rain stopped.", "until", "等到雨停用 until。"),
            Triple("The library added more seats near the windows. Students like the area because it is bright and ___.", "comfortable", "明亮且舒適符合語意。"),
            Triple("The teacher gave one example first. It made the difficult rule much ___ to understand.", "easier", "給例子會讓規則更容易理解。"),
            Triple("Nora saved part of her pocket money every week. She wanted to buy a gift ___ her grandmother.", "for", "buy something for someone。")
        )
        repeat(18) { round ->
            clozeItems.forEachIndexed { index, item ->
                questions.add(
                    Question(
                        "克漏字 ${round + 1}-${index + 1}: ${item.first}",
                        listOf(item.second, "unless", "quickly", "heavy").distinct(),
                        item.second,
                        item.third,
                        "會考克漏字上下文 ${round + 1}-${index + 1}",
                        "克漏字",
                        "先讀空格前後兩句，判斷語意關係再選答案。"
                    )
                )
            }
        }

        val readingItems = listOf(
            Triple("A poster says: Join the beach clean-up on Sunday. Meet at the bus stop at 8 a.m. Bags and gloves will be given there.", "Where should volunteers meet?", "At the bus stop."),
            Triple("A message says: Mom, I left my art homework on my desk. Could you bring it before the afternoon class?", "What does the writer need?", "The art homework."),
            Triple("A notice says: The basketball game will be moved to the gym because it may rain after lunch.", "Why is the game moved?", "Because it may rain."),
            Triple("A shop sign says: Show your student card and get 10% off on weekdays.", "Who can get a discount?", "Students with student cards."),
            Triple("An email says: Please upload the group report by 9 p.m. Late files will not be accepted.", "What should students do?", "Upload the report before 9 p.m."),
            Triple("A timetable says: The museum tour starts every 30 minutes from 10:00 a.m.", "If one tour starts at 10:30, when is the next one?", "At 11:00 a.m."),
            Triple("A short article says many people sleep better when they turn off phone notifications at night.", "What is the article mainly about?", "A way to sleep better."),
            Triple("A restaurant note says: Breakfast is served until 10:30. Lunch starts at 11:00.", "When does lunch start?", "At 11:00."),
            Triple("A text says: I will be late. Please buy two tickets first, and I will pay you later.", "What does the writer ask the friend to do?", "Buy two tickets first."),
            Triple("A club notice says: New members should bring a notebook and arrive ten minutes early.", "What should new members bring?", "A notebook.")
        )
        repeat(18) { round ->
            readingItems.forEachIndexed { index, item ->
                questions.add(
                    Question(
                        "閱讀理解 ${round + 1}-${index + 1}: ${item.first}\n${item.second}",
                        listOf(item.third, "Cancel the plan.", "Wait until next month.", "Call the hospital.").distinct(),
                        item.third,
                        "答案可由文本中的時間、地點、對象或請求推得。",
                        "會考閱讀生活文本 ${round + 1}-${index + 1}",
                        "閱讀理解",
                        "先看題目問什麼，再回文字找同義線索。"
                    )
                )
            }
        }

        val translationItems = listOf(
            "我正在等一位住在台中的朋友。" to "I am waiting for a friend who lives in Taichung.",
            "這個故事沒有我想像中那麼簡單。" to "This story is not as simple as I thought.",
            "請告訴我你昨天為什麼遲到。" to "Please tell me why you were late yesterday.",
            "如果你每天練習，你會更有信心。" to "If you practice every day, you will become more confident.",
            "她太緊張了，無法在大家面前說話。" to "She was too nervous to speak in front of everyone.",
            "這是我第一次參加英語比賽。" to "This is the first time I have joined an English contest.",
            "我們必須在下雨前回到學校。" to "We have to return to school before it rains.",
            "他花了十分鐘才找到正確答案。" to "It took him ten minutes to find the correct answer.",
            "我不知道這班公車是否會準時到。" to "I don't know whether this bus will arrive on time.",
            "老師提醒我們不要只背答案。" to "The teacher reminded us not to memorize only the answers.",
            "這張地圖對新學生很有幫助。" to "This map is helpful to new students.",
            "雖然題目很長，我還是先看問題。" to "Although the passage is long, I read the question first.",
            "他不但完成作業，也幫同學複習。" to "He not only finished his homework but also helped his classmates review.",
            "我想找一個可以安靜練習英文的地方。" to "I want to find a place where I can practice English quietly.",
            "這個活動讓我們更了解自己的社區。" to "This activity helped us understand our community better.",
            "請在回答前仔細閱讀公告。" to "Please read the notice carefully before answering."
        )
        repeat(12) { round ->
            translationItems.forEachIndexed { index, item ->
                questions.add(
                    Question(
                        "翻譯/句子重組 ${round + 1}-${index + 1}: 『${item.first}』最自然的英文是？",
                        listOf(
                            item.second,
                            item.second.replace("I ", "Me "),
                            item.second.replace(" is ", " are "),
                            item.second.replace(" to ", " for ")
                        ).distinct(),
                        item.second,
                        "注意主詞、動詞、時間副詞、連接詞與固定搭配。",
                        "會考翻譯句型 ${round + 1}-${index + 1}",
                        "翻譯/句子重組",
                        "先排主詞和動詞，再確認子句與時間位置。"
                    )
                )
            }
        }

        return questions
    }

    private fun buildQuestionBankItems(sourceQuestions: List<Question>): List<QuestionBankItem> {
        return sourceQuestions.mapIndexed { index, question ->
            val typeIndex = sourceQuestions.take(index + 1).count { it.type == question.type }
            QuestionBankItem(
                id = "cap-style-${(index + 1).toString().padStart(3, '0')}",
                level = levelFor(question.type, typeIndex),
                unit = unitFor(question.type),
                skill = skillFor(question.type),
                source = if (index < 8) "English+ seed" else "English+ CAP-style original",
                question = question,
                reviewState = if (index < 80) "approved" else "draft"
            )
        }
    }

    private fun levelFor(type: String, typeIndex: Int): String {
        return when (type) {
            "選擇題" -> if (typeIndex <= 8) "A1" else "A2"
            "填空題" -> if (typeIndex <= 8) "A2" else "B1"
            "克漏字" -> if (typeIndex <= 10) "A2" else "B1"
            "閱讀理解" -> if (typeIndex <= 10) "A2" else "B1"
            else -> if (typeIndex <= 6) "A2" else "B1"
        }
    }

    private fun unitFor(type: String): String {
        return when (type) {
            "填空題" -> "會考文法填空"
            "克漏字" -> "會考克漏字"
            "閱讀理解" -> "會考閱讀理解"
            "翻譯/句子重組" -> "翻譯與句子重組"
            else -> "入門文法與字彙"
        }
    }

    private fun skillFor(type: String): String {
        return when (type) {
            "填空題" -> "文法"
            "克漏字" -> "克漏字"
            "閱讀理解" -> "閱讀"
            "翻譯/句子重組" -> "翻譯"
            else -> "基礎"
        }
    }

    fun initialBreakpoints(): MutableList<Breakpoint> = mutableListOf(
        Breakpoint("be 動詞反覆錯", "高", "He am / He are 連續錯 3 次。", "AI 先把規則拆成 He is、They are 兩張小卡。", "志工只追問一件事：學生能不能說出 He 為什麼用 is。"),
        Breakpoint("看到長篇就停住", "中", "閱讀題停留超過 18 秒且沒有作答。", "平台先標出題型與線索，降低整篇閱讀壓力。", "老師下次補一張『先看題目，再回文章找線索』練習單。")
    )

    val roster = listOf(
        StudentRow("小安", "高", "be 動詞與填空題卡關", "需要志工接力 1 次"),
        StudentRow("阿柔", "中", "克漏字上下文判斷猶豫", "先給連接詞提示"),
        StudentRow("志豪", "低", "單字量不足", "可用離線單字包"),
        StudentRow("小晴", "中", "翻譯語序不穩", "適合句子重組練習"),
        StudentRow("宇翔", "低", "閱讀細節題穩定", "可安排主旨題挑戰")
    )

    val studyTasks = listOf(
        StudyTask("He is / She is 快速判斷", 3, "低", "先用一題建立成功感。", "推薦"),
        StudyTask("會考填空 3 題", 5, "中", "練 if 條件句、to V、關係代名詞。", "可開始"),
        StudyTask("克漏字短文一組", 6, "中", "練連接詞、上下文與片語。", "挑戰"),
        StudyTask("閱讀理解主旨題", 8, "高", "從文章整體判斷主旨，不只找單字。", "延伸")
    )

    val supportMessages = listOf(
        SupportMessage("AI 陪伴", "剛剛", "你不是不會英文，只是現在題型變難了。我們先把題目分成填空、克漏字、閱讀，再找線索。", "低壓"),
        SupportMessage("Emily 志工", "20:12", "小安今天願意挑戰會考填空，先肯定嘗試，再修一個規則。", "接力"),
        SupportMessage("老師", "昨天", "本週不公開排名，改看學生是否能從入門題走到會考挑戰題。", "教學提醒")
    )

    val weeklySignals = listOf(
        WeeklySignal("完成短任務", "4 次", "比上週多 1 次", "#0F766E"),
        WeeklySignal("會考挑戰題", "5 題", "已開始練克漏字與閱讀理解", "#246BFD"),
        WeeklySignal("高壓斷點", "1 次", "出現在長篇閱讀", "#B45309"),
        WeeklySignal("需要真人接力", "1 人", "已安排志工追蹤", "#B91C1C")
    )

    val mistakeRecords = listOf(
        MistakeRecord("He / She / It + is", "把 He 搭配成 am 或 are", "先念 He is，再做 2 題對照", "已修復一次"),
        MistakeRecord("if 條件句", "if 子句誤用 will rain", "記住 if + 現在式，主句 + will", "待複習"),
        MistakeRecord("克漏字連接詞", "轉折語意誤選 so", "先判斷前後句是因果還是轉折", "接力追蹤")
    )

    val offlinePacks = listOf(
        OfflinePack("3 分鐘 be 動詞包", "1.2 MB", "3-5 分鐘", "5 題判斷、2 張規則小卡、1 個反思問題"),
        OfflinePack("會考填空包", "1.4 MB", "5-8 分鐘", "條件句、to V、關係代名詞與語意填空"),
        OfflinePack("會考閱讀包", "1.8 MB", "8-10 分鐘", "公告、簡訊、短文主旨與細節題")
    )

    val mentorChecks = listOf(
        MentorCheck("低壓任務入口", "通過", "學生打開首頁後能很快看到今天先做什麼。", "#0F766E"),
        MentorCheck("題型難度梯度", "已加強", "題庫已從入門選擇題延伸到會考填空、克漏字、閱讀與翻譯。", "#0F766E"),
        MentorCheck("真人接力", "待實測", "需要用實際老師/志工確認摘要是否夠清楚。", "#B45309"),
        MentorCheck("離線保存", "已完成", "網路不穩時仍能先保存學習與接力紀錄。", "#0F766E"),
        MentorCheck("班級資料服務", "待連線", "若團隊提供服務網址，老師與志工可跨裝置更新紀錄。", "#B45309")
    )

    val handoffPriorities = listOf(
        HandoffPriority("小安 if 條件句高壓斷點", "Emily 志工", "陪他說出 if 子句為什麼不用 will rain", "高"),
        HandoffPriority("阿柔 克漏字轉折判斷", "英文老師", "示範先判斷前後句關係", "中"),
        HandoffPriority("志豪 單字量不足", "AI 陪伴", "安排 3 分鐘校園單字包", "低")
    )

    val journeySteps = listOf(
        JourneyStep("打開 App", "怕一打開就是考試", "首頁先問今天狀態，並給出一個小任務", "狀態低時先進復原任務"),
        JourneyStep("開始短任務", "擔心又答錯", "一題一概念，錯了也給下一步提示", "錯 2 次後生成接力摘要"),
        JourneyStep("挑戰會考題", "題目變長後容易慌", "先標示題型與解題線索，再逐步增加難度", "高壓斷點交給老師/志工"),
        JourneyStep("老師查看", "老師時間有限", "用待辦與優先序呈現誰需要先處理", "高風險斷點優先"),
        JourneyStep("回到學習", "怕再次失敗", "用錯題修復和小成就把信心接回來", "週報只呈現支持證據")
    )

    val interventionSteps = listOf(
        InterventionStep("心情低落", "改成 3 分鐘復原任務", "今天只完成一小步就好。", "學生仍願意回到任務"),
        InterventionStep("會考題太長", "先拆題型與線索", "這題不是要你一次讀懂全部，先看題目在問什麼。", "長題變成可操作步驟"),
        InterventionStep("主動求助", "把學生文字轉成志工摘要", "我卡在 if 句，不知道為什麼不能用 will rain。", "志工不需要重讀全部歷程"),
        InterventionStep("老師介入", "顯示下一步而非總分排名", "下一步只要確認 if + 現在式。", "避免公開比較造成壓力")
    )

    val designPrinciples = listOf(
        DesignPrinciple("主行動優先", "首頁第一眼要看到今天先做什麼。", "主按鈕導向心情檢測或短任務。"),
        DesignPrinciple("難度有梯度", "保留簡單題作下限，但讓進步的學生能挑戰會考題型。", "題庫包含 A1、A2、B1 與五種題型。"),
        DesignPrinciple("AI 不取代真人", "AI 處理可拆小的錯題，真人處理需要陪伴的斷點。", "handoff 摘要保留給老師/志工。"),
        DesignPrinciple("不公開排名", "偏鄉學生先需要安全感，不是再次被分數定義。", "週報呈現完成、修復與接力證據。")
    )

    val helpRequestOptions = listOf(
        HelpRequestOption("我看不懂題目", "我不知道這題在問什麼。", "平台先抓題型和關鍵線索，再生成接力摘要。", "AI 陪伴"),
        HelpRequestOption("我一直選錯", "我知道答案好像不對，但不知道差在哪裡。", "平台整理錯誤規則，交給志工追蹤。", "志工接力"),
        HelpRequestOption("題目太長", "我看到閱讀題就停住。", "切成先看題目、再找關鍵句。", "閱讀拆解"),
        HelpRequestOption("我想問老師", "我需要老師告訴我下一步。", "整理成老師可讀的一句話。", "老師接力")
    )

    val learningContracts = listOf(
        LearningContract("今天只做一小步", "我願意先做 3-5 分鐘。", "平台不會公開排名，只提供下一步。", "老師/志工只看需要支持的地方。"),
        LearningContract("錯題可以被修復", "我可以答錯，但要知道下一步。", "平台會把錯題拆成小規則。", "真人接力會看修復線索，不責備。"),
        LearningContract("會考題可以拆小", "我可以先找題型和線索。", "平台會先說明這是填空、克漏字、閱讀或翻譯。", "老師會看學生卡在哪一種題型。")
    )

    val reflectionPrompts = listOf(
        ReflectionPrompt("我完成了一小步", "我今天至少完成一題。", "已把這次完成放進學習地圖。", 3),
        ReflectionPrompt("我知道自己卡在哪裡", "我卡在 if 條件句。", "這會變成下一次修復任務。", 1),
        ReflectionPrompt("我需要人幫忙", "我想請志工看一下。", "平台會把摘要交給志工。", 0)
    )

    val teacherActions = listOf(
        TeacherAction("追蹤小安 if 條件句", "Emily 志工", "待處理", "今晚 21:00", "if 子句誤用 will rain。", "陪他完成 if + 現在式對照 2 題。"),
        TeacherAction("協助阿柔克漏字", "英文老師", "本週追蹤", "明天", "轉折連接詞判斷不穩。", "示範先判斷前後句關係。"),
        TeacherAction("確認離線包使用", "導師", "已安排", "本週五", "家中網路不穩。", "先下載會考填空包。")
    )

    val syncRecords = listOf(
        SyncRecord("短任務完成紀錄", "已保存", "已記錄 1 次 be 動詞練習。"),
        SyncRecord("會考題型進度", "待更新", "學生已開始克漏字與閱讀理解。"),
        SyncRecord("志工接力摘要", "已排隊", "等待班級資料服務連線。")
    )

    val localAccounts = listOf(
        LocalAccount("小安", AuthContract.ROLE_STUDENT, "YILAN-CHENGZHI-8A", "班級帳號"),
        LocalAccount("Emily", AuthContract.ROLE_VOLUNTEER, "MENTOR-GROUP-A", "志工帳號"),
        LocalAccount("林老師", AuthContract.ROLE_TEACHER, "CLASS-ENGLISH-02", "教師帳號")
    )

    val aiScenarios = listOf(
        AiScenario("會考填空修復", "學生回答 If it will rain tomorrow...", "卡在 if 條件句未來語意。", "先記：if 子句用現在式，主句才用 will。我們只重做一題。", "小安卡在 if 條件句，建議志工用 if it rains / we will stay home 對照。"),
        AiScenario("克漏字降壓", "學生看到短文題組就停住。", "不是整篇都不會，而是不知道先看哪裡。", "先看空格前後一句，判斷是轉折、因果、時間還是例子。", "學生需要先練連接詞和上下文線索。"),
        AiScenario("閱讀理解拆解", "學生說文章太長。", "情緒壓力高，應降低閱讀負擔。", "先讀題目問什麼，再回文章找同義線索，不用逐字翻譯。", "建議老師先示範一題主旨題。")
    )
}
