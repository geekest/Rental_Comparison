export type ListingStatus = "candidate" | "eliminated";
export type RentalType = "entire" | "shared";
export type CommuteMode = "subway" | "walking" | "driving";
export type Importance = "required" | "preferred" | "ignored";
export type ConditionResult = "met" | "conflict" | "unknown";
export type InspectionState = "unchecked" | "okay" | "issue";

export interface CostItem {
  id: string;
  name: string;
  amount?: number;
  cadence: "monthly" | "oneTime";
  refundable: boolean;
  confirmed: boolean;
}

export interface ConditionDefinition {
  id: string;
  name: string;
  importance: Importance;
  custom?: boolean;
}

export interface InspectionItem {
  id: string;
  name: string;
  state: InspectionState;
  note: string;
  photoIds: string[];
  hidden?: boolean;
  custom?: boolean;
}

export interface Listing {
  id: string;
  name: string;
  city: string;
  rentalType: RentalType;
  rent: number;
  prepaidRentMonths?: number;
  currency: "CNY";
  status: ListingStatus;
  focused: boolean;
  eliminationReason?: string;
  address?: string;
  sourceUrl?: string;
  area?: number;
  areaScope?: "whole" | "private";
  layout?: string;
  floor?: string;
  roomCount?: number;
  commuteMinutes?: number;
  commuteFare?: number;
  commuteMode?: CommuteMode;
  imageUrl?: string;
  screenshotId?: string;
  photoIds?: string[];
  costs: CostItem[];
  conditionResults: Record<string, ConditionResult>;
  inspections: InspectionItem[];
}

export const commuteModeLabels: Record<CommuteMode, string> = {
  subway: "地铁",
  walking: "步行",
  driving: "开车",
};

export const formatCommuteMode = (mode?: CommuteMode) => (mode ? commuteModeLabels[mode] : "方式待补充");

export interface DecisionEvent {
  id: string;
  type: "focused" | "unfocused" | "eliminated" | "restored" | "compared" | "confirmed" | "withdrawn";
  listingId: string;
  at: string;
  reason?: string;
}

export interface RentalTask {
  id: string;
  title: string;
  city: string;
  regionTemplate: "mainland-cn";
  currency: "CNY";
  areaUnit: "sqm";
  expectedMonths: number;
  commuteDestination: string;
  listings: Listing[];
  conditions: ConditionDefinition[];
  comparisonIds: string[];
  baselineId?: string;
  finalListingId?: string;
  finalReason?: string;
  events: DecisionEvent[];
  completed: boolean;
}

export interface FeedbackDraft {
  testId: string;
  category: "操作问题" | "信息不清" | "功能建议" | "其他";
  text: string;
  screenshotId?: string;
  screenshotConfirmed: boolean;
}

export interface AppState {
  version: 1;
  privacyAcknowledged: boolean;
  task: RentalTask;
  feedback: FeedbackDraft;
}

const defaultInspectionNames = [
  "采光与通风",
  "噪音",
  "潮湿与发霉",
  "水压与排水",
  "家电与设施",
  "安全与门禁",
  "网络信号",
  "周边环境",
  "图片与实物差异",
];

export const makeInspectionItems = (): InspectionItem[] =>
  defaultInspectionNames.map((name, index) => ({
    id: `inspection-${index + 1}`,
    name,
    state: "unchecked",
    note: "",
    photoIds: [],
  }));

export const initialState: AppState = {
  version: 1,
  privacyAcknowledged: false,
  task: {
    id: "task-shanghai-1",
    title: "上海租房计划",
    city: "上海",
    regionTemplate: "mainland-cn",
    currency: "CNY",
    areaUnit: "sqm",
    expectedMonths: 12,
    commuteDestination: "静安寺",
    comparisonIds: ["xuhui", "jingan"],
    baselineId: "xuhui",
    completed: false,
    events: [],
    conditions: [
      { id: "budget", name: "月均居住成本不超过 ¥9,500", importance: "required" },
      { id: "move-in", name: "在最晚日期前可入住", importance: "required" },
      { id: "rental-type", name: "符合整租或合租要求", importance: "preferred" },
      { id: "commute", name: "单程通勤不超过 40 分钟", importance: "required" },
      { id: "sunlight", name: "自然采光良好", importance: "preferred" },
      { id: "private", name: "拥有独立私人空间", importance: "preferred" },
      { id: "pet", name: "允许宠物", importance: "ignored" },
      { id: "elevator", name: "有电梯", importance: "ignored" },
      { id: "parking", name: "方便停车", importance: "ignored" },
      { id: "cooking", name: "允许做饭", importance: "preferred" },
    ],
    listings: [
      {
        id: "xuhui",
        name: "徐汇 · 一室一厅",
        city: "上海",
        rentalType: "entire",
        rent: 7800,
        prepaidRentMonths: 1,
        currency: "CNY",
        status: "candidate",
        focused: true,
        address: "徐汇区漕河泾附近",
        area: 48,
        areaScope: "whole",
        layout: "1 室 1 厅",
        floor: "8 / 18 层",
        roomCount: 1,
        commuteMinutes: 32,
        commuteFare: 6,
        commuteMode: "subway",
        imageUrl: "/assets/listings/xuhui.png",
        costs: [
          { id: "x-service", name: "物业与网络", amount: 450, cadence: "monthly", refundable: false, confirmed: true },
          {
            id: "x-utilities",
            name: "水电燃气预估",
            amount: 500,
            cadence: "monthly",
            refundable: false,
            confirmed: true,
          },
          { id: "x-deposit", name: "押金", amount: 7800, cadence: "oneTime", refundable: true, confirmed: false },
          { id: "x-agency", name: "中介费", amount: 6000, cadence: "oneTime", refundable: false, confirmed: true },
        ],
        conditionResults: { budget: "met", commute: "met", sunlight: "met", private: "met" },
        inspections: makeInspectionItems(),
      },
      {
        id: "jingan",
        name: "静安合租",
        city: "上海",
        rentalType: "shared",
        rent: 8200,
        prepaidRentMonths: 1,
        currency: "CNY",
        status: "candidate",
        focused: true,
        address: "静安区南京西路附近",
        area: 18,
        areaScope: "private",
        layout: "合租独立卧室",
        floor: "12 / 28 层",
        roomCount: 3,
        commuteMinutes: 14,
        commuteFare: 3,
        commuteMode: "walking",
        imageUrl: "/assets/listings/jingan.png",
        costs: [
          { id: "j-service", name: "服务与网络", amount: 180, cadence: "monthly", refundable: false, confirmed: true },
          { id: "j-deposit", name: "押金", amount: 8200, cadence: "oneTime", refundable: true, confirmed: true },
        ],
        conditionResults: { budget: "met", commute: "met", sunlight: "unknown", private: "met" },
        inspections: makeInspectionItems().map((item) =>
          item.id === "inspection-2" ? { ...item, state: "issue", note: "临街，关窗后仍能听到车流声。" } : item,
        ),
      },
      {
        id: "putuo",
        name: "普陀 · 开间",
        city: "上海",
        rentalType: "entire",
        rent: 6900,
        prepaidRentMonths: 1,
        currency: "CNY",
        status: "candidate",
        focused: false,
        area: 32,
        areaScope: "whole",
        layout: "开间",
        floor: "3 / 6 层",
        roomCount: 1,
        commuteMinutes: 46,
        commuteFare: 7,
        commuteMode: "driving",
        imageUrl: "/assets/listings/putuo.png",
        costs: [
          { id: "p-service", name: "物业费", amount: 280, cadence: "monthly", refundable: false, confirmed: true },
          { id: "p-deposit", name: "押金", cadence: "oneTime", refundable: true, confirmed: false },
        ],
        conditionResults: { budget: "met", commute: "conflict", sunlight: "met", private: "met" },
        inspections: makeInspectionItems(),
      },
    ],
  },
  feedback: {
    testId: `T-${Math.random().toString(36).slice(2, 8).toUpperCase()}`,
    category: "功能建议",
    text: "",
    screenshotConfirmed: false,
  },
};

export const createListing = (
  values: Pick<Listing, "name" | "city" | "rentalType" | "rent" | "currency">,
): Listing => ({
  ...values,
  id: crypto.randomUUID(),
  status: "candidate",
  focused: false,
  photoIds: [],
  costs: [],
  conditionResults: {},
  inspections: makeInspectionItems(),
});

const defaultConditions = (): ConditionDefinition[] => [
  { id: "budget", name: "月均居住成本不超过预算", importance: "required" },
  { id: "move-in", name: "在最晚日期前可入住", importance: "required" },
  { id: "rental-type", name: "符合整租或合租要求", importance: "preferred" },
  { id: "commute", name: "单程通勤时间不超过上限", importance: "required" },
  { id: "pet", name: "允许宠物", importance: "ignored" },
  { id: "elevator", name: "有电梯", importance: "ignored" },
  { id: "parking", name: "方便停车", importance: "ignored" },
  { id: "cooking", name: "允许做饭", importance: "preferred" },
];

export const createEmptyTask = (): RentalTask => ({
  id: crypto.randomUUID(),
  title: "新的选房任务",
  city: "",
  regionTemplate: "mainland-cn",
  currency: "CNY",
  areaUnit: "sqm",
  expectedMonths: 12,
  commuteDestination: "",
  listings: [],
  conditions: defaultConditions(),
  comparisonIds: [],
  events: [],
  completed: false,
});

export function getComparisonListings(task: RentalTask): Listing[] {
  const listings = task.comparisonIds
    .map((id) => task.listings.find((listing) => listing.id === id))
    .filter((listing): listing is Listing => Boolean(listing));
  if (!task.baselineId) return listings;
  return listings.sort((left, right) => {
    if (left.id === task.baselineId) return -1;
    if (right.id === task.baselineId) return 1;
    return 0;
  });
}

export function normalizeTask(task: RentalTask): RentalTask {
  const listings = task.listings.map((listing) => ({ ...listing, photoIds: listing.photoIds ?? [] }));
  const candidates = listings.filter((listing) => listing.status === "candidate");
  const candidateIds = new Set(candidates.map((listing) => listing.id));
  const comparisonIds = task.comparisonIds.filter((id) => candidateIds.has(id)).slice(0, 5);
  const baselineId = task.baselineId && comparisonIds.includes(task.baselineId) ? task.baselineId : comparisonIds[0];
  const finalStillExists = task.finalListingId && candidateIds.has(task.finalListingId);
  return {
    ...task,
    listings,
    comparisonIds,
    baselineId,
    finalListingId: finalStillExists ? task.finalListingId : undefined,
    finalReason: finalStillExists ? task.finalReason : undefined,
    completed: Boolean(finalStillExists && task.completed),
  };
}
