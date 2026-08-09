export interface OcrSuggestion {
  rent?: number;
  city?: string;
  text: string;
}

export async function recognizeListingScreenshot(
  file: File,
  onProgress: (progress: number) => void,
): Promise<OcrSuggestion> {
  const { createWorker } = await import("tesseract.js");
  const worker = await createWorker("chi_sim+eng", 1, {
    logger: (message) => {
      if (message.status === "recognizing text") onProgress(Math.round(message.progress * 100));
    },
  });
  try {
    const result = await worker.recognize(file);
    const text = result.data.text;
    const rentMatch = text.replaceAll(",", "").match(/(?:租金|月租|￥|¥)\s*([1-9]\d{2,5})/);
    const city = ["北京", "上海", "广州", "深圳", "杭州", "成都", "南京", "武汉", "重庆", "西安"].find((name) =>
      text.includes(name),
    );
    return { text, rent: rentMatch ? Number(rentMatch[1]) : undefined, city };
  } finally {
    await worker.terminate();
  }
}
