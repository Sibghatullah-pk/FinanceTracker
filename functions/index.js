const functions = require('firebase-functions');
const admin = require('firebase-admin');
const fetch = require('node-fetch');

admin.initializeApp();

// Scheduled daily function to generate AI insights for each household
// Configure GEMINI key in functions config (preferred):
// firebase functions:config:set gemini.key="<KEY>" gemini.model="models/text-bison-001"
// If GEMINI is not set, you can still set OpenAI key: firebase functions:config:set openai.key="<KEY>"
exports.dailyAiInsights = functions.pubsub.schedule('every 24 hours').onRun(async (context) => {
    const db = admin.firestore();
    const households = await db.collection('households').get();
    const geminiKey = functions.config().gemini?.key;
    const geminiModel = functions.config().gemini?.model || 'models/text-bison-001';
    const openaiKey = functions.config().openai?.key;
    if (!geminiKey && !openaiKey) {
        console.log('No AI key configured (GEMINI or OpenAI). Skipping.');
        return null;
    }

    for (const h of households.docs) {
        try {
            const hid = h.id;
            const data = h.data();
            // Gather recent transactions
            const txSnap = await db.collection('households').doc(hid).collection('transactions').orderBy('date', 'desc').limit(20).get();
            let prompt = `You are a helpful financial assistant. Household monthlyLimit: ${data.monthlyLimit || 0}\n`;
            let totalIncome = 0; let totalExpense = 0;
            const lines = [];
            txSnap.forEach(doc => {
                const t = doc.data();
                lines.push(`${t.date} | ${t.title} | ${t.category} | ${t.type} | ${t.amount}`);
                if (t.type === 'income') totalIncome += Number(t.amount || 0);
                else totalExpense += Number(t.amount || 0);
            });
            prompt += `Total income: ${totalIncome}\nTotal expenses: ${totalExpense}\nRecent:\n` + lines.join('\n');
            prompt += '\nProvide: 1) short summary; 2) 3 suggestions; 3) projection for next month.';

            let content = '';
            if (geminiKey) {
                const gemUrl = `https://generativelanguage.googleapis.com/v1beta2/${geminiModel}:generateText?key=${geminiKey}`;
                const gemRes = await fetch(gemUrl, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({
                        prompt: { text: prompt },
                        maxOutputTokens: 400
                    })
                });
                const gemJson = await gemRes.json();
                content = gemJson.candidates?.[0]?.output || '';
            } else {
                const res = await fetch('https://api.openai.com/v1/chat/completions', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                        'Authorization': `Bearer ${openaiKey}`
                    },
                    body: JSON.stringify({
                        model: 'gpt-3.5-turbo',
                        messages: [{ role: 'user', content: prompt }],
                        max_tokens: 400,
                    })
                });
                const json = await res.json();
                content = json.choices?.[0]?.message?.content || '';
            }
            await db.collection('households').doc(hid).collection('ai_insights').add({
                text: content,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                source: 'scheduled'
            });
            console.log(`Stored AI insight for household ${hid}`);
        } catch (e) {
            console.error('Error for household', h.id, e);
        }
    }

    return null;
});
