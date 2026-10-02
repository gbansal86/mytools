# 01 — Eight-scene pilot: TRAINING vs USING AI (v0.3)

**Title:** “How AI Answers Fast (It Learned Before You Asked)”  
**One thing to remember:** Training learns patterns first. Using the trained model (inference) produces a new output later. Humans check important results.  
**Status:** Provisional spoken script, not recorded; current 60-second **silent** animatic is a preproduction prototype.

The editable script is in [voice_script_v03.txt](voice_script_v03.txt) (99 words). Approximate scene times are placeholders until a licensed natural voice read-through is recorded and measured.

| Approx. time | Narration | Motion design & word-cued annotations |
|---|---|---|
| 00–05 | AI can answer in seconds. How did it learn? | Question card appears immediately; earlier training timeline extends. Callout “Learned before you asked”. |
| 05–12 | Two stages: training first. Using the trained model comes later. | Example moves to TRAINING; connection then draws to USE MODEL (not examples directly into use). Callout “TWO STAGES”. |
| 12–22 | Imagine emails marked spam or genuine. During training, a model sees many examples and learns patterns. | Multiple labeled emails physically move down converging paths; track red and green separately. Callout “LABELED EXAMPLES”. |
| 22–30 | It adjusts internal settings called parameters to improve predictions. | Node links pulse, meter changes. Callout “PARAMETERS”; network icon is only an explanatory metaphor. |
| 30–39 | Now a new email arrives. The trained model predicts if it's spam. That's inference, not training from scratch. | A NEW input moves through an ALREADY TRAINED model to output “LIKELY SPAM”. Callout “INFERENCE ≠ TRAINING”. |
| 39–48 | Generative AI follows the same broad split: learn during training, then create new words or images when prompted. | Prompt travels into trained model, text/image emerges. Callout “GENERATE AT USE TIME”. |
| 48–55 | Confident answers can still be wrong. Check important claims against reliable sources. | Claim and source visibly compared; uncertainty stays visible. Callout “VERIFY”. |
| 55–60 | Remember: training learns; inference answers; humans check. | A four-node mind map unfolds: EXAMPLES → TRAIN → USE → CHECK; ensure legible final hold. |

## Voice direction
Warm, curious, conversational. No imitation of a particular real presenter. Pause after the opening question and before the recap. Record, listen on a phone and **measure** duration before retiming animation. Do not pitch-shift or race through lines to force the 60-second constraint.

## Factual guardrails
This describes a common training/inference distinction for trained AI models, not every AI application. Some systems use retrieval, feedback, adaptation or separately scheduled retraining; a new query does not inherently trigger full retraining. Classifications are predictions, not guarantees. A mind-map/brain metaphor is not literal computation.

## Prototype vs final
[render_animatic.py](render_animatic.py) is the motion/timing proof; it intentionally has no narrator, has temporary labels and does not meet the polished 3D or 1080×1920 final release criteria. See [06_PROTOTYPE_STATUS.md](06_PROTOTYPE_STATUS.md) for the exact next gate.
