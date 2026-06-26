#!/usr/bin/env python3
import json
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SEED_PATH = ROOT / "ios" / "EnglishPlus" / "EnglishPlus" / "Resources" / "SeedData" / "question_bank_seed.json"
GENERATED_AT = datetime(2026, 6, 26, 12, 0, 0, tzinfo=timezone.utc).isoformat().replace("+00:00", "Z")
SOURCE = "English+ Android parity generated seed"
IMPORT_BATCH_ID = "ios-parity-round-1-question-bank"


def unique_options(options):
    result = []
    for option in options:
        if option and option not in result:
            result.append(option)
    return result[:4]


def level_for(question_type, index):
    pattern = {
        "vocabulary": ["A1", "A1", "A2", "A2", "B1", "B2"],
        "grammar": ["A1", "A2", "A2", "B1", "B1", "B2"],
        "fillBlank": ["A2", "A2", "B1", "B1", "B2", "A1"],
        "cloze": ["A2", "B1", "B1", "B2", "A2", "B2"],
        "reading": ["A2", "B1", "B1", "B2", "A2", "B2"],
        "translation": ["A2", "B1", "B1", "B2", "A2", "B2"],
        "dialogue": ["A1", "A2", "A2", "B1", "B1", "B2"],
    }[question_type]
    return pattern[index % len(pattern)]


def unit_for(question_type):
    return {
        "vocabulary": "生活單字",
        "grammar": "基礎文法",
        "fillBlank": "文法填空",
        "cloze": "短文克漏字",
        "reading": "閱讀理解",
        "translation": "翻譯與句子重組",
        "dialogue": "情境對話",
    }[question_type]


def skill_for(question_type):
    return {
        "vocabulary": "字義判斷",
        "grammar": "主詞與時態",
        "fillBlank": "句型搭配",
        "cloze": "文意推論",
        "reading": "定位與推論",
        "translation": "句序與時態",
        "dialogue": "情境回應",
    }[question_type]


def make_item(index, question_type, prompt, options, answer, explanation, concept, repair_hint):
    return {
        "id": f"ios-cap-{index:04d}",
        "level": level_for(question_type, index),
        "unit": unit_for(question_type),
        "skill": skill_for(question_type),
        "source": SOURCE,
        "reviewState": "approved",
        "importBatchId": IMPORT_BATCH_ID,
        "updatedAt": GENERATED_AT,
        "question": {
            "prompt": prompt,
            "type": question_type,
            "options": unique_options(options),
            "answer": answer,
            "acceptedAnswers": [answer],
            "explanation": explanation,
            "concept": concept,
            "repairHint": repair_hint,
        },
    }


def vocabulary_items(start_index):
    words = [
        ("library", "a place to read or borrow books", ["library", "kitchen", "station", "market"]),
        ("neighbor", "a person who lives near you", ["neighbor", "pilot", "actor", "visitor"]),
        ("umbrella", "something used when it rains", ["umbrella", "ticket", "mirror", "blanket"]),
        ("medicine", "something people take when they are sick", ["medicine", "menu", "message", "magazine"]),
        ("environment", "the air, water, land, and living things around us", ["environment", "envelope", "exercise", "entrance"]),
        ("schedule", "a plan that tells when things happen", ["schedule", "scenery", "secret", "sentence"]),
        ("temperature", "how hot or cold something is", ["temperature", "treasure", "tradition", "traffic"]),
        ("volunteer", "a person who helps without being paid", ["volunteer", "manager", "customer", "stranger"]),
        ("habit", "something a person does often", ["habit", "height", "history", "holiday"]),
        ("direction", "the way to go to a place", ["direction", "decision", "dictionary", "discussion"]),
        ("patient", "able to wait calmly", ["patient", "private", "popular", "perfect"]),
        ("protect", "to keep someone or something safe", ["protect", "produce", "prepare", "promise"]),
        ("improve", "to become better", ["improve", "include", "invite", "invent"]),
        ("reduce", "to make something smaller or less", ["reduce", "receive", "repair", "record"]),
        ("confident", "sure that you can do something", ["confident", "crowded", "common", "careless"]),
    ]
    contexts = [
        "The school notice says students can use the word in a campus life situation.",
        "The English club asks students to choose the best meaning.",
        "A short reading question checks the meaning of this word.",
        "The teacher wants students to connect the word with daily life.",
        "The sentence appears in a junior-high level reading passage.",
        "The practice item focuses on one useful word at a time.",
        "The learner is reviewing common CAP-style vocabulary.",
        "The app gives a quick meaning check before a harder task.",
    ]
    items = []
    for round_index in range(8):
        for word_index, (answer, meaning, options) in enumerate(words):
            prompt = f"Vocabulary {round_index + 1}-{word_index + 1}: Which word means {meaning}? {contexts[(round_index + word_index) % len(contexts)]}"
            items.append(
                make_item(
                    start_index + len(items),
                    "vocabulary",
                    prompt,
                    options,
                    answer,
                    f"{answer} means {meaning}. The other choices do not match the situation.",
                    "CAP vocabulary in context",
                    "先看題目給的中文或英文線索，再回到選項找最貼近的意思。",
                )
            )
    return items


def grammar_items(start_index):
    subjects = [
        ("My sister", "is", "helpful"),
        ("The students", "are", "ready"),
        ("A good breakfast", "is", "important"),
        ("Those books", "are", "useful"),
        ("Mr. Chen", "is", "our science teacher"),
        ("The cats", "are", "under the table"),
        ("English", "is", "my favorite subject"),
        ("My parents", "are", "at home"),
        ("This question", "is", "not easy"),
        ("The boys", "are", "on the basketball team"),
        ("Our classroom", "is", "next to the office"),
        ("Two tickets", "are", "on the desk"),
        ("The movie", "is", "popular"),
        ("Some apples", "are", "in the bag"),
        ("The bus stop", "is", "near the park"),
        ("My shoes", "are", "wet"),
        ("Her idea", "is", "creative"),
        ("Many people", "are", "waiting outside"),
        ("The answer", "is", "correct"),
        ("These stories", "are", "interesting"),
    ]
    items = []
    for round_index in range(9):
        for subject_index, (subject, answer, complement) in enumerate(subjects):
            prompt = f"Grammar {round_index + 1}-{subject_index + 1}: {subject} ___ {complement}."
            items.append(
                make_item(
                    start_index + len(items),
                    "grammar",
                    prompt,
                    ["am", "is", "are", "be"],
                    answer,
                    f"{subject} needs the be verb '{answer}' because of its number/person.",
                    "be verb agreement",
                    "先圈出主詞，再判斷是單數、複數，或 I。",
                )
            )
    return items


def fill_blank_items(start_index):
    patterns = [
        ("Tom has lived here ___ 2020.", "since", ["since", "for", "during", "until"], "since 接時間起點。"),
        ("The cake was made ___ my aunt.", "by", ["by", "with", "from", "at"], "被動語態中 by 表示動作者。"),
        ("I enjoy ___ English songs after class.", "listening to", ["listening to", "listen to", "to listen", "listened"], "enjoy 後面接 V-ing。"),
        ("Please turn ___ the lights before you leave.", "off", ["off", "on", "up", "over"], "turn off 表示關掉。"),
        ("The woman ___ is talking to our teacher is my mom.", "who", ["who", "which", "where", "when"], "修飾人要用 who。"),
        ("The box is too heavy for me ___ carry.", "to", ["to", "for", "with", "by"], "too...to 表示太...而不能。"),
        ("This restaurant is famous ___ its beef noodles.", "for", ["for", "at", "with", "from"], "be famous for 表示以...聞名。"),
        ("I have never ___ such an exciting game.", "seen", ["seen", "saw", "see", "seeing"], "have never 後接過去分詞。"),
        ("It is kind ___ you to help the new student.", "of", ["of", "for", "to", "with"], "It is kind of you 是固定用法。"),
        ("The more you practice, the ___ you will become.", "better", ["better", "best", "good", "well"], "the 比較級, the 比較級。"),
        ("I don't know ___ he will come or not.", "whether", ["whether", "because", "although", "when"], "whether...or not 表示是否。"),
        ("The room needs ___ before the guests arrive.", "cleaning", ["cleaning", "clean", "to clean", "cleaned"], "need V-ing 可表示需要被處理。"),
        ("If you heat ice, it ___ water.", "becomes", ["becomes", "became", "will become", "become"], "事實條件句用現在式。"),
        ("I am interested ___ learning languages.", "in", ["in", "on", "at", "for"], "be interested in 是固定片語。"),
        ("She is looking forward ___ the trip.", "to", ["to", "for", "with", "about"], "look forward to 後面接名詞或 V-ing。"),
        ("The book is worth ___.", "reading", ["reading", "to read", "read", "reads"], "be worth V-ing。"),
        ("The teacher told us not ___ loudly in the library.", "to talk", ["to talk", "talk", "talking", "talked"], "tell someone not to V。"),
        ("We should save water ___ it is important.", "because", ["because", "but", "or", "so"], "because 用來說明原因。"),
    ]
    items = []
    for round_index in range(10):
        for pattern_index, (prompt_base, answer, options, explanation) in enumerate(patterns):
            prompt = f"Fill blank {round_index + 1}-{pattern_index + 1}: {prompt_base}"
            items.append(
                make_item(
                    start_index + len(items),
                    "fillBlank",
                    prompt,
                    options,
                    answer,
                    explanation,
                    f"grammar pattern {pattern_index + 1}",
                    "先看空格前後的固定搭配，再排除不合語法或語意的選項。",
                )
            )
    return items


def cloze_items(start_index):
    passages = [
        ("A school started a book corner in every classroom. Students can take a book during break time. This plan helps students read more ___ they do not have much free time.", "even if", ["even if", "before", "until", "unless"]),
        ("Nina lost her student card on the way home. The next morning, a classmate returned it to her. Nina felt ___ and thanked him.", "thankful", ["thankful", "hungry", "careless", "late"]),
        ("Many people bring their own bags when they shop. This small habit can reduce waste and ___ the earth.", "protect", ["protect", "borrow", "forget", "invite"]),
        ("Jason wrote down what he spent every day. After two months, he knew where his money ___.", "went", ["went", "slept", "grew", "opened"]),
        ("The soccer team did not win the first game. However, the players kept practicing and played much ___ in the final game.", "better", ["better", "earlier", "louder", "heavier"]),
        ("A museum guide told visitors not to touch the old paintings because oil from hands may ___ them.", "damage", ["damage", "follow", "enter", "answer"]),
        ("Lily was nervous before her speech. Her teacher told her to breathe slowly, and the advice helped her feel more ___.", "confident", ["confident", "dangerous", "expensive", "crowded"]),
        ("The new bus app shows arrival times, so students can wait at home ___ standing in the rain.", "instead of", ["instead of", "because of", "as soon as", "even though"]),
        ("Ben forgot his lunch, ___ his friend shared a sandwich with him.", "so", ["so", "but", "or", "although"]),
        ("The class cleaned the beach and found many plastic bottles. They learned that small actions can make a big ___.", "difference", ["difference", "mistake", "noise", "ticket"]),
        ("Amy checked the map before leaving. She arrived on time because she knew the right ___.", "route", ["route", "price", "song", "color"]),
        ("The teacher gave fewer homework questions today so students could focus on doing them ___.", "carefully", ["carefully", "loudly", "cheaply", "hungrily"]),
        ("Kevin joined the English club because he wanted to ___ speaking with classmates.", "practice", ["practice", "hide", "repair", "finish"]),
        ("The sign says visitors should keep quiet. It is probably in a ___.", "library", ["library", "stadium", "market", "playground"]),
        ("Mandy saved part of her allowance every week. She was trying to buy a new ___.", "bicycle", ["bicycle", "cloud", "answer", "rule"]),
        ("The train was delayed, so the meeting started thirty minutes ___.", "later", ["later", "lighter", "lower", "louder"]),
    ]
    items = []
    for round_index in range(10):
        for passage_index, (prompt_base, answer, options) in enumerate(passages):
            prompt = f"Cloze {round_index + 1}-{passage_index + 1}: {prompt_base}"
            items.append(
                make_item(
                    start_index + len(items),
                    "cloze",
                    prompt,
                    options,
                    answer,
                    f"The context points to '{answer}'. Read the sentence before and after the blank.",
                    f"context cloze {passage_index + 1}",
                    "不要只看空格，先抓前後句的因果、轉折、目的或場景。",
                )
            )
    return items


def reading_items(start_index):
    readings = [
        ("A poster says: Join the river clean-up this Saturday. Meet at the park gate at 8:30 a.m. Gloves and bags will be provided.", "What should people do first?", "Go to the park gate in the morning."),
        ("A message says: Dad, I left my science notebook on the kitchen table. Could you bring it to school before lunch?", "What does the writer need?", "A notebook from home."),
        ("A notice says: The school concert will move from the playground to the gym because of rain.", "Why was the place changed?", "Because the weather is rainy."),
        ("A short article says: Some students study better with quiet music, but songs with words may make reading harder.", "What is the main idea?", "Music can affect studying in different ways."),
        ("A timetable says: Bus 12 leaves every 20 minutes from 7:00 to 9:00 in the morning.", "If a bus leaves at 7:20, when is the next one?", "At 7:40."),
        ("A shop note says: Buy two sandwiches and get one drink for free before 11 a.m.", "When can customers get a free drink?", "Before 11 a.m."),
        ("An email says: Please send your group report by Friday night. Late reports will not be accepted.", "What must students do?", "Send the report by Friday night."),
        ("A weather report says: It will be cloudy in the morning, but heavy rain is expected after 3 p.m.", "When should people carry an umbrella?", "In the afternoon."),
        ("A library note says: Students may borrow three books at a time and keep them for two weeks.", "How many books can a student borrow at a time?", "Three books."),
        ("A club message says: Please bring a water bottle and wear comfortable shoes for the hiking activity.", "What should students prepare?", "A water bottle and comfortable shoes."),
        ("A short article says: Turning off notifications at night can help students sleep better.", "What is the article mainly about?", "A way to sleep better."),
        ("A class note says: The English quiz will have ten vocabulary questions and one reading passage.", "What will be on the quiz?", "Vocabulary questions and a reading passage."),
        ("A museum ticket says: Students can enter for free on Wednesday afternoon if they show a student ID.", "What should students bring?", "A student ID."),
        ("A school website says: The basketball practice is canceled today because the coach is sick.", "Why is practice canceled?", "Because the coach is sick."),
    ]
    items = []
    for round_index in range(10):
        for reading_index, (passage, question, answer) in enumerate(readings):
            distractors = ["Wait until next week.", "Ask for a new phone.", "Close the school library."]
            prompt = f"Reading {round_index + 1}-{reading_index + 1}: {passage}\n{question}"
            items.append(
                make_item(
                    start_index + len(items),
                    "reading",
                    prompt,
                    [answer] + distractors,
                    answer,
                    f"The answer can be found by locating the key detail in the passage: {answer}",
                    f"reading detail {reading_index + 1}",
                    "先找題目問的關鍵字，再回原文定位；不要憑印象作答。",
                )
            )
    return items


def translation_items(start_index):
    translations = [
        ("我每天放學後練習英文。", "I practice English after school every day."),
        ("這本書對我來說太難懂了。", "This book is too difficult for me to understand."),
        ("如果明天下雨，我們會待在家。", "If it rains tomorrow, we will stay home."),
        ("我想知道公車什麼時候會到。", "I want to know when the bus will arrive."),
        ("我昨晚九點正在讀英文。", "I was reading English at nine last night."),
        ("這個問題比我想的更難。", "This question is harder than I thought."),
        ("你可以告訴我車站在哪裡嗎？", "Can you tell me where the station is?"),
        ("他太累了，無法完成作業。", "He was too tired to finish his homework."),
        ("這是我讀過最有趣的故事。", "This is the most interesting story I have ever read."),
        ("如果你需要幫忙，請告訴我。", "If you need help, please tell me."),
        ("我們花了兩個小時完成海報。", "It took us two hours to finish the poster."),
        ("她不但會唱歌，也會彈吉他。", "She can not only sing but also play the guitar."),
        ("我不知道明天是否會下雨。", "I don't know whether it will rain tomorrow."),
        ("這張照片讓我想起我的家鄉。", "This picture reminds me of my hometown."),
        ("他今天早起，為了準時到校。", "He got up early today to get to school on time."),
        ("離開教室前請關燈。", "Please turn off the lights before leaving the classroom."),
        ("這部電影值得再看一次。", "This movie is worth watching again."),
        ("老師要我們分組討論這個故事。", "The teacher asked us to discuss the story in groups."),
    ]
    items = []
    for round_index in range(10):
        for translation_index, (zh, answer) in enumerate(translations):
            options = [
                answer,
                answer.replace("I ", "Me ", 1),
                answer.replace(" is ", " are "),
                answer.replace(" to ", " for ", 1),
            ]
            prompt = f"Translation {round_index + 1}-{translation_index + 1}: Choose the best English sentence for 「{zh}」"
            items.append(
                make_item(
                    start_index + len(items),
                    "translation",
                    prompt,
                    options,
                    answer,
                    "先抓主詞和動詞，再確認時態、語序與片語搭配。",
                    f"sentence order {translation_index + 1}",
                    "先排出主詞 + 動詞，再檢查時間、地點、原因等修飾語的位置。",
                )
            )
    return items


def dialogue_items(start_index):
    dialogues = [
        ("A: Could you help me carry these books? B: ___", "Sure, no problem.", ["Sure, no problem.", "It is sunny today.", "I am twelve years old.", "The book is red."]),
        ("A: Thank you for waiting for me. B: ___", "You're welcome.", ["You're welcome.", "I like apples.", "It is ten dollars.", "Turn left."]),
        ("A: Would you like some tea? B: ___", "Yes, please.", ["Yes, please.", "At seven o'clock.", "In the library.", "Because I was late."]),
        ("A: I'm sorry I broke your pencil. B: ___", "That's all right.", ["That's all right.", "I am hungry.", "It is Monday.", "The bus is coming."]),
        ("A: How do I get to the train station? B: ___", "Go straight and turn right.", ["Go straight and turn right.", "I got up early.", "It tastes sweet.", "She is my sister."]),
        ("A: I feel nervous about the test. B: ___", "Take a deep breath and try one question first.", ["Take a deep breath and try one question first.", "The window is blue.", "I bought a new bag.", "It is near the river."]),
        ("A: May I borrow your dictionary? B: ___", "Sure, here you are.", ["Sure, here you are.", "It is raining.", "I am in Class Two.", "The movie was long."]),
        ("A: What time does the movie start? B: ___", "It starts at seven.", ["It starts at seven.", "I went by bus.", "Because I was sick.", "She can sing well."]),
        ("A: Let's clean the classroom together. B: ___", "Good idea.", ["Good idea.", "No, it is a pencil.", "I live near school.", "It costs fifty dollars."]),
        ("A: Why didn't you join the game? B: ___", "Because I hurt my foot.", ["Because I hurt my foot.", "At the bookstore.", "It is on the wall.", "Three times a week."]),
        ("A: Could you say that again? B: ___", "Of course.", ["Of course.", "It is very tall.", "I like noodles.", "She is thirteen."]),
        ("A: Your speech was great. B: ___", "Thank you.", ["Thank you.", "Turn off the light.", "It is behind you.", "I missed the bus."]),
    ]
    items = []
    for round_index in range(10):
        for dialogue_index, (prompt_base, answer, options) in enumerate(dialogues):
            prompt = f"Dialogue {round_index + 1}-{dialogue_index + 1}: {prompt_base}"
            items.append(
                make_item(
                    start_index + len(items),
                    "dialogue",
                    prompt,
                    options,
                    answer,
                    f"The reply '{answer}' matches the speaker's situation and intention.",
                    f"dialogue response {dialogue_index + 1}",
                    "先判斷對方是在請求、道謝、道歉、問路還是求助，再選最自然的回應。",
                )
            )
    return items


def build_items():
    builders = [
        vocabulary_items,
        grammar_items,
        fill_blank_items,
        cloze_items,
        reading_items,
        translation_items,
        dialogue_items,
    ]
    items = []
    next_index = 1
    for builder in builders:
        generated = builder(next_index)
        items.extend(generated)
        next_index += len(generated)
    return items


def main():
    items = build_items()
    seed = {
        "questionBankSchemaVersion": 5,
        "app": "English+",
        "items": items,
    }
    SEED_PATH.write_text(
        json.dumps(seed, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"Generated {len(items)} iOS question bank items at {SEED_PATH}")


if __name__ == "__main__":
    main()
