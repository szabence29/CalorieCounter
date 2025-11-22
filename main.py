from fastapi import FastAPI
from pydantic import BaseModel
from openai import OpenAI
import os, json
from dotenv import load_dotenv
from datetime import date

# source venv/bin/activate
# uvicorn main:app --reload --port 8000
# deactivate

load_dotenv()

app = FastAPI()
client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))

class NLInput(BaseModel):
    text: str

BASE_SYSTEM_PROMPT = """
Today is {today}.
You are a nutrition assistant for a calorie tracking mobile app.

Task
-----
The user writes in natural language what they ate and drank.
Your job is to extract a structured command in the following JSON schema:

NLCommand = {{
  "intent": "log",
  "entities": {{
    "items": [
      {{ "name": "string", "quantity": 0, "unit": "string" }}
    ],
    "meal": "string|null",
    "date": "string|null"
  }},
  "missing_fields": ["string"]
}}

General rules
-------------
- Always return ONE single JSON object that exactly matches the NLCommand schema.
- Do NOT include any explanations, comments or extra keys. Only the JSON object.
- The app UI is in English, so use English in field values (except for brand names).
- For EVERY item, you SHOULD provide a numeric quantity and a unit. Avoid nulls.
  It is acceptable to approximate typical amounts as long as they are realistic.

Allowed units
-------------
In the JSON, use only these unit values:
- "g"   for grams (solid foods)
- "ml"  for milliliters (drinks / liquids)
- "pcs" for whole pieces (eggs, bananas, apples, cookies, etc.)

Explicit amounts (no approximation needed)
------------------------------------------
If the user clearly gives a numeric amount, convert it mechanically:

- If the user says grams (g, gram, grams, kg, kilograms):
  -> convert to grams and use unit "g".
  Example: "0.5 kg chicken" -> quantity: 500, unit: "g".

- If the user says milliliters or liters (ml, milliliter, liter, l):
  -> convert to milliliters and use unit "ml".
  Example: "0.3 l of juice" -> quantity: 300, unit: "ml".

- If the user gives a count of whole items (e.g. "2 bananas", "3 eggs", "5 cookies"):
  -> use quantity = count, unit = "pcs".

Approximate amounts for vague serving sizes
-------------------------------------------
The user may use vague serving sizes like:
"bowl", "plate", "serving", "slice", "piece", "cup", "mug", "glass",
"handful", "spoon", "teaspoon", "tablespoon", "some", "a little bit", etc.

In these cases, you MUST estimate a realistic typical quantity.
It does NOT need to be perfect; it just needs to be reasonable.

Guidelines (typical ranges, not exact science):
- A handful of berries      -> about 30 g
- A handful of nuts        -> about 30 g
- A slice of bread         -> about 30 g
- A slice of pizza         -> about 110 g
- A bowl of oatmeal        -> about 60 g (dry oats)
- A bowl of pasta          -> about 200 g (cooked)
- A small glass of juice   -> about 150 ml
- A mug/cup of coffee or tea -> about 200 ml
- A teaspoon of honey or sugar -> about 7 g
- A tablespoon of peanut butter -> about 15 g
- A small yogurt cup       -> about 125 g
- A sandwich               -> about 100–150 g (prefer ~120 g)
- A small cake slice       -> about 60 g
- A salad bowl             -> about 150–250 g (prefer ~200 g)
- A spoon of oil or butter -> about 5–10 g (prefer ~7 g)

Rules for approximations:
- When you see such vague servings, choose a value in the typical range and
  use the mid-range "preferred" value unless the text clearly suggests more or less.
- NEVER output units like "serving", "bowl", "slice", "cup", "handful", "spoon" etc.
  Always convert them into "g" or "ml" based on the food type.
- Semi-solid foods like yogurt, pudding, or cottage cheese should use "g", not "ml".
- Be consistent: solid foods → "g", liquids → "ml", whole countables → "pcs".
- The goal is to give a plausible, typical estimate, not an exact measurement.
  Being slightly off (e.g. 30 g vs 40 g) is acceptable.

Meals
-----
The app has these meal types: "breakfast", "lunch", "dinner", "snack".

Rules:
- If the text clearly describes a single meal, set "meal" accordingly.
  ("for breakfast", "this morning" → breakfast;
   "for lunch", "at noon" → lunch;
   "for dinner", "tonight", "this evening", "last night" → dinner;
   "as a snack" → snack)
- If multiple meals are described but the schema allows only one meal, you may:
  - choose the most relevant meal for the majority of items, OR
  - set "meal": null and include "meal" in missing_fields.
- Do NOT assume a meal type just from the food kind (e.g. coffee → snack).
- Do NOT concatenate multiple meals into one string (no "breakfast, lunch").

Dates
-----
- When the user says "today", use "{today}".
- When the user says "yesterday", use the previous day of {today}.
- When the user says "tomorrow", use the next day after {today}.
- If the user does not mention any date at all, ASSUME the entry is for {today}.

Output format
-------------
- Always respond with ONLY the JSON object, nothing else.
- The JSON must be syntactically valid and parseable.
"""

@app.post("/nl-command")
def parse_command(body: NLInput):
    today = date.today().isoformat()
    system_prompt = BASE_SYSTEM_PROMPT.format(today=today)

    completion = client.chat.completions.create(
        model="gpt-5",
        response_format={"type": "json_object"},
        messages=[
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": body.text},
        ],
    )
    return json.loads(completion.choices[0].message.content)

# ---------------------------------------------------------------------
# Benchmark route – összehasonlítja gpt-4o-mini és gpt-5 modellek eredményét
# ---------------------------------------------------------------------

TEST_SENTENCES = [
    "Had two small pancakes with a bit of maple syrup and a cup of milk this morning.",
    "I grabbed a sandwich and a latte around noon.",
    "A handful of almonds, a slice of cheese and half an apple.",
    "Yesterday evening I had pasta with tomato sauce and a little olive oil.",
    "Drank a protein shake and ate one banana after my run.",
    "For dinner I ate soup, two slices of bread and a piece of chocolate.",
    "This morning I just had some coffee and a few biscuits.",
    "I had sushi for lunch — 6 pieces with soy sauce.",
    "Just water and a small yogurt cup today.",
    "A big bowl of salad with some chicken pieces and a drizzle of dressing."
]

MODELS = ["gpt-4o-mini", "gpt-5"]

def call_model(model: str, prompt: str, text: str):
    completion = client.chat.completions.create(
        model=model,
        response_format={"type": "json_object"},
        messages=[
            {"role": "system", "content": prompt},
            {"role": "user", "content": text},
        ],
    )
    try:
        return json.loads(completion.choices[0].message.content)
    except json.JSONDecodeError:
        return {"error": "Invalid JSON response", "raw": completion.choices[0].message.content}


@app.get("/benchmark")
def benchmark_models():
    today = date.today().isoformat()
    system_prompt = BASE_SYSTEM_PROMPT.format(today=today)

    results = {}
    for sentence in TEST_SENTENCES:
        entry = {"input": sentence, "models": {}}
        for model in MODELS:
            res = call_model(model, system_prompt, sentence)
            entry["models"][model] = res
        results[sentence] = entry

    diffs = []
    for s, entry in results.items():
        if len(MODELS) < 2:
            continue
        m1, m2 = MODELS[0], MODELS[1]
        r1, r2 = entry["models"][m1], entry["models"][m2]
        if "error" in r1 or "error" in r2:
            continue
        meal1 = r1.get("entities", {}).get("meal")
        meal2 = r2.get("entities", {}).get("meal")
        if meal1 != meal2:
            diffs.append({
                "sentence": s,
                "field": "meal",
                m1: meal1,
                m2: meal2
            })

    return {
        "summary": {
            "tested_models": MODELS,
            "sentence_count": len(TEST_SENTENCES),
            "differences_found": len(diffs)
        },
        "differences": diffs,
        "full_results": results
    }