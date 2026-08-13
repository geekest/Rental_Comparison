import type { CostCadence, Listing } from "./domain";

export interface OcrCostSuggestion {
  name: string;
  amount?: number;
  cadence: CostCadence;
  refundable: boolean;
}

export interface OcrSuggestion {
  rent?: number;
  city?: string;
  currency?: string;
  address?: string;
  area?: number;
  layout?: string;
  floor?: string;
  hasElevator?: boolean;
  availableDate?: string;
  leaseMonths?: number;
  paymentCadence?: Listing["paymentCadence"];
  costs: OcrCostSuggestion[];
  text: string;
}

const knownCities = ["北京", "上海", "广州", "深圳", "杭州", "成都", "南京", "武汉", "重庆", "西安"];
const paymentCadenceMap: Array<[RegExp, NonNullable<Listing["paymentCadence"]>]> = [
  [/月付|押一付一|付一/, "monthly"],
  [/季付|押一付三|付三/, "quarterly"],
  [/半年付|押一付六|付六/, "semiAnnual"],
  [/年付|押一付十二|付十二/, "annual"],
];

function extractAmount(text: string, label: string) {
  const match = text.replaceAll(",", "").match(new RegExp(`${label}[^\\d]{0,8}([1-9]\\d{1,6})`));
  return match ? Number(match[1]) : undefined;
}

function extractCosts(text: string): OcrCostSuggestion[] {
  const labels: Array<[string, boolean]> = [
    ["押金", true],
    ["中介费", false],
    ["物业费", false],
    ["服务费", false],
    ["网费", false],
  ];
  return labels.flatMap(([name, refundable]) => {
    const amount = extractAmount(text, name);
    return amount === undefined ? [] : [{ name, amount, cadence: "oneTime" as const, refundable }];
  });
}

export function parseListingText(text: string): OcrSuggestion {
  const compactText = text.replaceAll(",", "");
  const rentMatch = compactText.match(/(?:租金|月租|￥|¥)\s*([1-9]\d{2,6})/);
  const areaMatch = compactText.match(/([1-9]\d{1,3}(?:\.\d+)?)\s*(?:㎡|平米|平方米)/);
  const layoutMatch = compactText.match(/([1-9]\s*[室房]\s*[0-9]?\s*[厅卫])/);
  const floorMatch = compactText.match(/(?:楼层|第)\s*([\d]+\s*(?:\/|层)[\d]+\s*层?)/);
  const dateMatch = compactText.match(/(?:可入住|入住时间|起租)\D{0,6}(20\d{2}[-./年]\d{1,2}(?:[-./月]\d{1,2})?)/);
  const leaseMatch = compactText.match(/(?:租期|合同期)\D{0,6}(\d{1,2})\s*个?月/);
  const addressMatch = compactText.match(/((?:[\u4e00-\u9fa5]{2,8}(?:区|县|镇|街道|路|街|弄|号))[^\n]{0,30})/);
  const payment = paymentCadenceMap.find(([pattern]) => pattern.test(compactText))?.[1];
  return {
    text,
    rent: rentMatch ? Number(rentMatch[1]) : undefined,
    city: knownCities.find((name) => compactText.includes(name)),
    currency: compactText.includes("$") || compactText.includes("美元") ? "USD" : "CNY",
    address: addressMatch?.[1]?.trim(),
    area: areaMatch ? Number(areaMatch[1]) : undefined,
    layout: layoutMatch?.[1]?.replace(/\s/g, " "),
    floor: floorMatch?.[1]?.replace(/\s/g, ""),
    hasElevator: /有电梯|电梯房/.test(compactText) ? true : /无电梯|没有电梯/.test(compactText) ? false : undefined,
    availableDate: dateMatch?.[1]?.replace(/[年./]/g, "-"),
    leaseMonths: leaseMatch ? Number(leaseMatch[1]) : undefined,
    paymentCadence: payment,
    costs: extractCosts(compactText),
  };
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
    return parseListingText(result.data.text);
  } finally {
    await worker.terminate();
  }
}
