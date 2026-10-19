// ponytail: Server-side LLM backend using OpenAI-compatible chat completions with vision.

import express from 'express';
import cors from 'cors';
import fs from 'node:fs';
import path from 'node:path';

// Load .env if present
const envPath = path.resolve(process.cwd(), '.env');
if (fs.existsSync(envPath)) {
  const lines = fs.readFileSync(envPath, 'utf8').split('\n');
  for (const line of lines) {
    const trimmed = line.trim();
    if (trimmed && !trimmed.startsWith('#') && trimmed.includes('=')) {
      const idx = trimmed.indexOf('=');
      const key = trimmed.slice(0, idx).trim();
      const val = trimmed.slice(idx + 1).trim();
      if (!process.env[key]) {
        process.env[key] = val;
      }
    }
  }
}

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json({ limit: '30mb' }));

// Health Check
app.get('/api/health', (req, res) => {
  res.json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    llm_configured: Boolean(process.env.LLM_API_KEY),
    model: process.env.LLM_MODEL || 'gpt-4o-mini',
    base_url: process.env.LLM_BASE_URL || 'https://api.openai.com/v1',
  });
});

// Update LLM config at runtime
app.post('/api/config', (req, res) => {
  const { api_key, base_url, model } = req.body;
  if (api_key) process.env.LLM_API_KEY = api_key;
  if (base_url) process.env.LLM_BASE_URL = base_url;
  if (model) process.env.LLM_MODEL = model;

  res.json({
    success: true,
    message: 'Configuration updated successfully',
    model: process.env.LLM_MODEL || 'gpt-4o-mini',
    base_url: process.env.LLM_BASE_URL || 'https://api.openai.com/v1',
    llm_configured: Boolean(process.env.LLM_API_KEY),
  });
});

// Analyze Receipt via OpenAI completion API
app.post('/api/analyze-receipt', async (req, res) => {
  try {
    const { image_base64, mime_type = 'image/jpeg' } = req.body;

    if (!image_base64) {
      return res.status(400).json({ success: false, error: 'Missing image_base64 in request body.' });
    }

    const apiKey = process.env.LLM_API_KEY;
    const rawBaseUrl = process.env.LLM_BASE_URL || 'https://api.openai.com/v1';
    const baseUrl = rawBaseUrl.endsWith('/') ? rawBaseUrl.slice(0, -1) : rawBaseUrl;
    const model = process.env.LLM_MODEL || 'gpt-4o-mini';

    if (!apiKey) {
      return res.status(500).json({
        success: false,
        error: 'LLM_API_KEY is not configured on the server. Please supply LLM_API_KEY in .env or via /api/config.',
      });
    }

    const endpoint = `${baseUrl}/chat/completions`;

    const prompt = `
Bạn là chuyên gia bóc tách hóa đơn thanh toán bán lẻ tại Việt Nam.
Hãy đọc thật kỹ ảnh hóa đơn này (tên cửa hàng/thương hiệu, ngày giờ, từng dòng sản phẩm bao gồm số lượng/khối lượng kg, đơn giá, chiết khấu, và tổng tiền thanh toán).

Yêu cầu xuất ra DUY NHẤT một JSON hợp lệ (không kèm bất kỳ văn bản giải thích nào) theo cấu trúc:
{
  "merchant": "Tên thương hiệu hoặc cửa hàng (VD: WinMart, Highlands Coffee, Circle K...)",
  "date": "YYYY-MM-DD",
  "total_amount": số tiền thực tế khách cần thanh toán hoặc đã thanh toán (số thực, không chứa dấu phẩy/chấm),
  "subtotal": tổng tiền hàng trước giảm giá/khấu trừ (số thực),
  "discount": số tiền giảm giá, khuyến mãi hoặc voucher nếu có (số thực, mặc định 0),
  "category": "Food" | "Transport" | "Study" | "Shopping" | "Entertainment" | "Other",
  "items": [
    {
      "name": "Tên đầy đủ của sản phẩm/món hàng",
      "quantity": số lượng hoặc khối lượng kg (số thực, VD: 1, 0.35),
      "unit_price": đơn giá (số thực),
      "total_price": thành tiền của món hàng sau khi tính số lượng (số thực)
    }
  ]
}
Lưu ý quan trọng:
1. 'total_amount' là con số THỰC TẾ CHI TRẢ (Tiền cần thanh toán / Tổng thanh toán). Tuyệt đối KHÔNG lấy số điện thoại khách hàng, mã cửa hàng, số điểm tích lũy hoặc số tiền thối/tiền mặt khách đưa.
2. Trích xuất đầy đủ tất cả các món hàng trong danh sách hàng hóa.
`;

    const payload = {
      model,
      messages: [
        {
          role: 'user',
          content: [
            { type: 'text', text: prompt },
            {
              type: 'image_url',
              image_url: {
                url: `data:${mime_type};base64,${image_base64}`,
              },
            },
          ],
        },
      ],
      response_format: { type: 'json_object' },
      temperature: 0.1,
    };

    console.log(`[LLM] Calling ${endpoint} with model=${model}...`);

    const response = await fetch(endpoint, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${apiKey}`,
      },
      body: JSON.stringify(payload),
    });

    if (!response.ok) {
      const errText = await response.text();
      console.error(`[LLM Error] Status ${response.status}:`, errText);
      return res.status(response.status).json({
        success: false,
        error: `LLM API Error (${response.status}): ${errText}`,
      });
    }

    const data = await response.json();
    const rawContent = data.choices?.[0]?.message?.content;

    if (!rawContent) {
      return res.status(500).json({ success: false, error: 'Empty content received from LLM completion.' });
    }

    const cleanJson = rawContent.trim().replace(/^```json\s*/, '').replace(/\s*```$/, '');
    const parsed = JSON.parse(cleanJson);

    return res.json({
      success: true,
      data: {
        merchant: parsed.merchant || 'Unknown Merchant',
        total_amount: Number(parsed.total_amount) || 0,
        subtotal: Number(parsed.subtotal) || Number(parsed.total_amount) || 0,
        discount: Number(parsed.discount) || 0,
        date: parsed.date || new Date().toISOString().split('T')[0],
        category: parsed.category || 'Shopping',
        items: Array.isArray(parsed.items) ? parsed.items.map(it => ({
          name: it.name || 'Món hàng',
          quantity: Number(it.quantity) || 1,
          unit_price: Number(it.unit_price) || 0,
          total_price: Number(it.total_price) || 0,
        })) : [],
      },
    });
  } catch (err) {
    console.error('[Server Error]:', err);
    return res.status(500).json({ success: false, error: err.message || 'Internal Server Error' });
  }
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Receipt Expense Server running on port ${PORT}`);
  console.log(`Endpoint: http://localhost:${PORT}/api/analyze-receipt`);
  console.log(`Health:   http://localhost:${PORT}/api/health`);
});
