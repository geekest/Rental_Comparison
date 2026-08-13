import {
  CheckCircledIcon,
  ChevronLeftIcon,
  ChevronRightIcon,
  ClockIcon,
  DownloadIcon,
  ExclamationTriangleIcon,
  GearIcon,
  HomeIcon,
  ImageIcon,
  MagnifyingGlassIcon,
  MixerHorizontalIcon,
  PlusIcon,
  QuestionMarkCircledIcon,
  ResetIcon,
  StarFilledIcon,
  TrashIcon,
} from "@radix-ui/react-icons";
import { useEffect, useRef, useState } from "react";
import { calculateCosts, formatMoney, getInspectionIssues, getRequiredConflicts } from "./calculations";
import {
  type AppState,
  type ConditionResult,
  commuteModeLabels,
  createEmptyTask,
  createListing,
  formatCommuteMode,
  getComparisonListings,
  type InspectionState,
  initialState,
  type Listing,
  normalizeTask,
} from "./domain";
import { BottomSheet, Carousel, KeyboardInput, KeyboardTextarea, MobileScroll, useKeyboard } from "./mobile";
import { type OcrSuggestion, recognizeListingScreenshot } from "./ocr";
import { buildDecisionReport, buildTestSummary, downloadText } from "./report";
import { loadMedia, loadState, saveMedia, saveState } from "./storage";
import "./prototype.css";

type Tab = "listings" | "compare" | "conditions";
type CompareSection = "cost" | "commute" | "conditions" | "inspection";
type Sheet = "add" | "detail" | "task" | "manage" | "eliminate" | "final" | "feedback" | "result" | null;

const cloneInitialState = () => structuredClone(initialState);

export default function Prototype() {
  const keyboard = useKeyboard();
  const [state, setState] = useState<AppState>(cloneInitialState);
  const [ready, setReady] = useState(false);
  const [tab, setTab] = useState<Tab>("listings");
  const [sheet, setSheet] = useState<Sheet>(null);
  const [selectedId, setSelectedId] = useState("xuhui");
  const [compareSection, setCompareSection] = useState<CompareSection>("cost");
  const [toast, setToast] = useState("");

  useEffect(() => {
    loadState()
      .then((saved) => {
        if (saved) setState(saved);
        setReady(true);
      })
      .catch(() => setReady(true));
  }, []);

  useEffect(() => {
    if (!ready) return;
    const timer = window.setTimeout(() => saveState(state).catch(() => setToast("保存失败，请先导出结果。")), 120);
    return () => window.clearTimeout(timer);
  }, [state, ready]);

  useEffect(() => {
    void tab;
    void sheet;
    const frame = window.requestAnimationFrame(() => {
      const screen = document.querySelector<HTMLElement>('[data-testid="device-screen"]');
      if (screen) screen.scrollTop = 0;
    });
    return () => window.cancelAnimationFrame(frame);
  }, [tab, sheet]);

  const updateTask = (transform: (task: AppState["task"]) => AppState["task"]) =>
    setState((current) => ({ ...current, task: normalizeTask(transform(current.task)) }));

  const selected = state.task.listings.find((listing) => listing.id === selectedId) ?? state.task.listings[0];
  const comparison = getComparisonListings(state.task);

  const dismissKeyboard = () => {
    keyboard.hide();
    if (document.activeElement instanceof HTMLElement) document.activeElement.blur();
    const screen = document.querySelector<HTMLElement>('[data-testid="device-screen"]');
    if (screen) screen.scrollTop = 0;
  };

  const openSheet = (next: Sheet, listingId?: string) => {
    dismissKeyboard();
    if (listingId) setSelectedId(listingId);
    setSheet(next);
  };

  const toggleComparison = (id: string) => {
    updateTask((task) => {
      const included = task.comparisonIds.includes(id);
      if (!included && task.comparisonIds.length >= 5) {
        setToast("最多比较 5 套房源");
        return task;
      }
      return {
        ...task,
        comparisonIds: included ? task.comparisonIds.filter((item) => item !== id) : [...task.comparisonIds, id],
      };
    });
  };

  const setListing = (listingId: string, patch: Partial<Listing>) =>
    updateTask((task) => ({
      ...task,
      listings: task.listings.map((listing) => (listing.id === listingId ? { ...listing, ...patch } : listing)),
    }));

  const eliminate = (listing: Listing, reason = "") => {
    updateTask((task) => {
      const at = new Date().toISOString();
      const isEliminatingFinal = listing.status === "candidate" && task.finalListingId === listing.id;
      return {
        ...task,
        listings: task.listings.map((item) =>
          item.id === listing.id
            ? {
                ...item,
                status: listing.status === "candidate" ? "eliminated" : "candidate",
                focused: false,
                eliminationReason: listing.status === "candidate" ? reason.trim() || undefined : undefined,
              }
            : item,
        ),
        events: [
          ...task.events,
          ...(isEliminatingFinal
            ? [{ id: crypto.randomUUID(), type: "withdrawn" as const, listingId: listing.id, at }]
            : []),
          {
            id: crypto.randomUUID(),
            type: listing.status === "candidate" ? "eliminated" : "restored",
            listingId: listing.id,
            at,
            reason: listing.status === "candidate" ? reason.trim() || undefined : undefined,
          },
        ],
      };
    });
    setToast(listing.status === "candidate" ? "已淘汰，可随时恢复" : "已恢复到候选池");
  };

  const toggleFocus = (listing: Listing) => {
    updateTask((task) => ({
      ...task,
      listings: task.listings.map((item) => (item.id === listing.id ? { ...item, focused: !item.focused } : item)),
      events: [
        ...task.events,
        {
          id: crypto.randomUUID(),
          type: listing.focused ? "unfocused" : "focused",
          listingId: listing.id,
          at: new Date().toISOString(),
        },
      ],
    }));
  };

  const withdrawFinal = () => {
    updateTask((task) => ({
      ...task,
      finalListingId: undefined,
      finalReason: undefined,
      completed: false,
      events: task.finalListingId
        ? [
            ...task.events,
            {
              id: crypto.randomUUID(),
              type: "withdrawn",
              listingId: task.finalListingId,
              at: new Date().toISOString(),
            },
          ]
        : task.events,
    }));
    setSheet(null);
    setTab("compare");
    setToast("已撤回最终选择，可继续比较");
  };

  return (
    <div className="prototype-app" data-testid="rental-app">
      {!state.privacyAcknowledged ? (
        <PrivacyNotice onConfirm={() => setState((current) => ({ ...current, privacyAcknowledged: true }))} />
      ) : null}
      {tab === "listings" ? (
        <ListingsScreen
          state={state}
          onOpen={openSheet}
          onCompare={toggleComparison}
          onEliminate={(listing) =>
            listing.status === "candidate" ? openSheet("eliminate", listing.id) : eliminate(listing)
          }
        />
      ) : tab === "compare" ? (
        <CompareScreen
          state={state}
          listings={comparison}
          section={compareSection}
          onSection={setCompareSection}
          onManage={() => openSheet("manage")}
          onFinal={() => openSheet("final")}
          onReplace={() => openSheet("manage")}
        />
      ) : (
        <ConditionsScreen state={state} setState={setState} onOpenListing={(id) => openSheet("detail", id)} />
      )}
      <BottomNav
        tab={tab}
        onChange={(nextTab) => {
          dismissKeyboard();
          if (nextTab === "compare" && state.task.comparisonIds.length >= 2) {
            updateTask((task) =>
              task.events.some((event) => event.type === "compared")
                ? task
                : {
                    ...task,
                    events: [
                      ...task.events,
                      {
                        id: crypto.randomUUID(),
                        type: "compared",
                        listingId: task.baselineId ?? task.comparisonIds[0],
                        at: new Date().toISOString(),
                      },
                    ],
                  },
            );
          }
          setTab(nextTab);
        }}
        compareCount={state.task.comparisonIds.length}
      />
      {toast ? <Toast message={toast} onDone={() => setToast("")} /> : null}

      <BottomSheet
        open={sheet === "add"}
        onOpenChange={(open) => !open && setSheet(null)}
        title="添加租赁方案"
        description="先保存 5 个必要字段，其他信息之后再补。"
        snap={0.9}
      >
        <AddListingForm
          city={state.task.city}
          onSave={(listing) => {
            updateTask((task) => ({ ...task, listings: [...task.listings, listing] }));
            setSelectedId(listing.id);
            setSheet("detail");
          }}
        />
      </BottomSheet>

      <BottomSheet
        open={sheet === "detail"}
        onOpenChange={(open) => !open && setSheet(null)}
        title={selected?.name ?? "房源详情"}
        description="未知信息可以保留，确认后才参与比较。"
        snap={0.92}
      >
        {selected ? (
          <ListingEditor
            task={state.task}
            listing={selected}
            onChange={(patch) => setListing(selected.id, patch)}
            onToggleFocus={() => toggleFocus(selected)}
          />
        ) : null}
      </BottomSheet>

      <BottomSheet
        open={sheet === "task"}
        onOpenChange={(open) => !open && setSheet(null)}
        title="选房任务设置"
        description="任务包含多套可以互相比较的租赁方案。"
        snap={0.76}
      >
        <TaskEditor
          state={state}
          setState={setState}
          onCreateNew={() => {
            if (!window.confirm("创建新任务会替换当前设备中的选房任务。请先导出需要保留的结果，确认继续吗？")) return;
            setState((current) => ({ ...current, task: createEmptyTask() }));
            setSelectedId("");
            setTab("listings");
            setSheet(null);
            setToast("已创建新的选房任务");
          }}
        />
      </BottomSheet>

      <BottomSheet
        open={sheet === "manage"}
        onOpenChange={(open) => !open && setSheet(null)}
        title="管理比较房源"
        description="选择 2～5 套，并指定一个仅用于对齐差异的基准。"
        snap={0.82}
      >
        <CompareManager state={state} updateTask={updateTask} />
      </BottomSheet>

      <BottomSheet
        open={sheet === "eliminate"}
        onOpenChange={(open) => !open && setSheet(null)}
        title="淘汰这套房源"
        description="原因可以不填，之后仍可恢复到候选池。"
        snap={0.55}
      >
        {selected ? (
          <EliminateDecision
            key={selected.id}
            listing={selected}
            onConfirm={(reason) => {
              eliminate(selected, reason);
              setSheet(null);
            }}
          />
        ) : null}
      </BottomSheet>

      <BottomSheet
        open={sheet === "final"}
        onOpenChange={(open) => !open && setSheet(null)}
        title="确认最终房源"
        description="系统只整理事实，最终决定由你完成。"
        snap={0.78}
      >
        <FinalDecision state={state} updateTask={updateTask} onDone={() => setSheet("result")} />
      </BottomSheet>

      <BottomSheet
        open={sheet === "result"}
        onOpenChange={(open) => !open && setSheet(null)}
        title="本次决策结果"
        description="导出前请注意：数据仅保存在当前设备。"
        snap={0.9}
      >
        <ResultSheet state={state} onWithdraw={withdrawFinal} onFeedback={() => setSheet("feedback")} />
      </BottomSheet>

      <BottomSheet
        open={sheet === "feedback"}
        onOpenChange={(open) => !open && setSheet(null)}
        title="反馈问题"
        description="不会自动附带页面、房源、截图或照片。"
        snap={0.78}
      >
        <FeedbackForm state={state} setState={setState} />
      </BottomSheet>
    </div>
  );
}

function ListingsScreen({
  state,
  onOpen,
  onCompare,
  onEliminate,
}: {
  state: AppState;
  onOpen: (sheet: Sheet, id?: string) => void;
  onCompare: (id: string) => void;
  onEliminate: (listing: Listing) => void;
}) {
  const candidates = state.task.listings.filter((listing) => listing.status === "candidate");
  const eliminated = state.task.listings.filter((listing) => listing.status === "eliminated");
  return (
    <MobileScroll className="app-screen" key="listings-screen">
      <main className="listings-screen" data-testid="candidate-screen">
        <header className="hero-header">
          <div>
            <p className="eyebrow">正在整理</p>
            <h1>{state.task.title}</h1>
            <p>
              {candidates.length} 套候选 · {state.task.listings.filter((item) => item.focused).length} 套重点考虑
            </p>
          </div>
          <button className="round-button" aria-label="任务设置" onClick={() => onOpen("task")}>
            <MixerHorizontalIcon />
          </button>
        </header>
        <Carousel className="listing-carousel" contentClassName="listing-track" ariaLabel="候选房源">
          {candidates.map((listing) => {
            const costs = calculateCosts(listing, state.task.expectedMonths);
            const unknownCount = costs.unknowns.length;
            const isCompared = state.task.comparisonIds.includes(listing.id);
            return (
              <article className="listing-card" key={listing.id} data-testid={`listing-card-${listing.id}`}>
                <button className="card-eliminate" aria-label="淘汰" onClick={() => onEliminate(listing)}>
                  <TrashIcon />
                </button>
                <div className="card-main">
                  <ListingPhotoGallery listing={listing} />
                  <button className="card-detail-button" onClick={() => onOpen("detail", listing.id)}>
                    <div className="card-body">
                      <div className="card-title-row">
                        <h2>{listing.name}</h2>
                        {listing.focused ? (
                          <span className="focus-mark">
                            <StarFilledIcon /> 重点
                          </span>
                        ) : null}
                      </div>
                      <p className="rent">
                        <span>¥</span> {listing.rent.toLocaleString("zh-CN")}
                        <small> / 月</small>
                      </p>
                      <dl className="card-facts">
                        <div>
                          <ClockIcon />
                          <dt>通勤</dt>
                          <dd>
                            {formatCommuteMode(listing.commuteMode)} · {listing.commuteMinutes ?? "?"} 分钟
                          </dd>
                        </div>
                        <div>
                          <HomeIcon />
                          <dt>{formatRentalRooms(listing)}</dt>
                          <dd>
                            {listing.area
                              ? `${listing.area} ㎡${listing.areaScope === "private" ? " 私人空间" : " 整套"}`
                              : "面积未知"}
                          </dd>
                        </div>
                        <div>
                          <span className="fact-icon">层</span>
                          <dt>楼层</dt>
                          <dd>{listing.floor || "待补充"}</dd>
                        </div>
                      </dl>
                      {unknownCount > 0 ? (
                        <span className="warning-chip">
                          {costs.unknowns[0]}待确认{unknownCount > 1 ? ` +${unknownCount - 1}` : ""}
                        </span>
                      ) : (
                        <span className="complete-chip">
                          <CheckCircledIcon /> 关键信息已确认
                        </span>
                      )}
                    </div>
                  </button>
                </div>
                <div className="card-actions">
                  <button
                    className={isCompared ? "primary-button selected" : "primary-button"}
                    aria-pressed={isCompared}
                    onClick={() => onCompare(listing.id)}
                  >
                    {isCompared ? "已加入对比" : "加入对比"}
                  </button>
                  <button className="secondary-button" onClick={() => onOpen("detail", listing.id)}>
                    查看详情
                  </button>
                </div>
              </article>
            );
          })}
          <button className="add-card" onClick={() => onOpen("add")}>
            <span>
              <PlusIcon />
            </span>
            <strong>添加房源</strong>
            <small>手动录入或从截图识别</small>
          </button>
        </Carousel>
        <div className="page-dots" aria-hidden="true">
          <i className="active" />
          <i />
          <i />
          <i />
        </div>
        <button className="disclosure-card" onClick={() => onOpen("manage")}>
          <span>
            <strong>查看真实成本与条件</strong>
            <small>
              {state.task.comparisonIds.length >= 2
                ? `已选择 ${state.task.comparisonIds.length} 套，可开始比较`
                : "至少选择 2 套房源"}
            </small>
          </span>
          <ChevronRightIcon />
        </button>
        {state.task.finalListingId ? (
          <button className="decision-banner" onClick={() => onOpen("result")}>
            <CheckCircledIcon />
            <span>
              <strong>已确认最终房源</strong>
              <small>{state.task.listings.find((item) => item.id === state.task.finalListingId)?.name}</small>
            </span>
            <ChevronRightIcon />
          </button>
        ) : null}
        {eliminated.length ? (
          <section className="eliminated">
            <h2>已淘汰</h2>
            {eliminated.map((listing) => (
              <button key={listing.id} onClick={() => onEliminate(listing)}>
                <span>
                  <strong>{listing.name}</strong>
                  <small>
                    ¥{listing.rent.toLocaleString("zh-CN")} / 月
                    {listing.eliminationReason ? ` · ${listing.eliminationReason}` : ""}
                  </small>
                </span>
                <span className="restore-action">
                  <ResetIcon /> 恢复
                </span>
              </button>
            ))}
          </section>
        ) : null}
      </main>
    </MobileScroll>
  );
}

function formatRentalRooms(listing: Listing) {
  const rentalType = listing.rentalType === "entire" ? "整租" : "合租";
  return listing.roomCount ? `${rentalType} ${listing.roomCount} 居` : `${rentalType} 居室待补充`;
}

function ListingPhotoGallery({ listing }: { listing: Listing }) {
  const mediaKey = [listing.screenshotId, ...(listing.photoIds ?? [])]
    .filter((id): id is string => Boolean(id))
    .join(",");
  const [localPhotos, setLocalPhotos] = useState<Array<{ id: string; url: string }>>([]);

  useEffect(() => {
    let active = true;
    let objectUrls: string[] = [];
    const mediaIds = mediaKey ? mediaKey.split(",") : [];
    if (!mediaIds.length) {
      setLocalPhotos([]);
      return () => undefined;
    }
    void Promise.all(mediaIds.map((id) => loadMedia(id)))
      .then((media) => {
        const photos = media.flatMap((item, index) => {
          if (!item) return [];
          const url = URL.createObjectURL(item);
          return [{ id: mediaIds[index], url }];
        });
        objectUrls = photos.map((photo) => photo.url);
        if (active) setLocalPhotos(photos);
      })
      .catch(() => {
        if (active) setLocalPhotos([]);
      });
    return () => {
      active = false;
      objectUrls.forEach((url) => {
        URL.revokeObjectURL(url);
      });
    };
  }, [mediaKey]);

  const photos = [...(listing.imageUrl ? [{ id: "default", url: listing.imageUrl }] : []), ...localPhotos];
  const sources = photos.length ? photos : [{ id: "fallback", url: "/assets/listings/putuo.png" }];
  if (sources.length === 1)
    return <img className="listing-media-image" src={sources[0].url} alt="" draggable={false} />;
  return (
    <Carousel
      className="listing-media-carousel"
      contentClassName="listing-media-track"
      ariaLabel={`${listing.name} 的照片`}
    >
      {sources.map((source) => (
        <img className="listing-media-image" src={source.url} alt="" draggable={false} key={source.id} />
      ))}
    </Carousel>
  );
}

function CompareScreen({
  state,
  listings,
  section,
  onSection,
  onManage,
  onFinal,
  onReplace,
}: {
  state: AppState;
  listings: Listing[];
  section: CompareSection;
  onSection: (section: CompareSection) => void;
  onManage: () => void;
  onFinal: () => void;
  onReplace: () => void;
}) {
  if (listings.length < 2)
    return (
      <MobileScroll className="app-screen" key="compare-empty-screen">
        <main className="empty-state">
          <span>
            <MixerHorizontalIcon />
          </span>
          <h1>先选择 2 套房源</h1>
          <p>比较只呈现同口径事实，不会给出综合分或替你推荐。</p>
          <button className="primary-button" onClick={onManage}>
            选择房源
          </button>
        </main>
      </MobileScroll>
    );
  const baseline = state.task.baselineId;
  return (
    <MobileScroll className="app-screen" key="compare-screen">
      <main className="compare-screen" data-testid="compare-screen">
        <header className="compare-header">
          <button aria-label="返回房源">
            <ChevronLeftIcon />
          </button>
          <h1>比较房源</h1>
          <button onClick={onManage}>调整</button>
        </header>
        <Carousel className="compare-head-carousel" contentClassName="compare-head-track" ariaLabel="参与比较的房源">
          {listings.map((listing) => (
            <article className="compare-head" key={listing.id}>
              <img src={listing.imageUrl} alt="" />
              <strong>{listing.name}</strong>
              <small>{listing.id === baseline ? "比较基准" : "与基准比较"}</small>
              <button onClick={onReplace}>更换</button>
            </article>
          ))}
        </Carousel>
        <div className="segment-control" role="tablist">
          {(
            [
              ["cost", "成本"],
              ["commute", "通勤"],
              ["conditions", "条件"],
              ["inspection", "看房"],
            ] as const
          ).map(([id, label]) => (
            <button key={id} className={section === id ? "active" : ""} onClick={() => onSection(id)}>
              {label}
            </button>
          ))}
        </div>
        <CompareSectionContent task={state.task} listings={listings} section={section} />
        <section className="no-score">
          <QuestionMarkCircledIcon />
          <p>
            <strong>这里没有综合总分</strong>
            <br />
            先看差异、冲突与未知，再由你决定。
          </p>
        </section>
        <button className="sticky-cta" onClick={onFinal}>
          确认最终房源
        </button>
      </main>
    </MobileScroll>
  );
}

function CompareSectionContent({
  task,
  listings,
  section,
}: {
  task: AppState["task"];
  listings: Listing[];
  section: CompareSection;
}) {
  if (section === "cost")
    return (
      <section className="comparison-section">
        <SectionTitle icon={<GearIcon />} title="真实成本" subtitle="月租与固定费用的月均支出" />
        <MetricRail
          listings={listings}
          render={(listing) => {
            const cost = calculateCosts(listing, task.expectedMonths);
            return (
              <>
                <strong>
                  {formatMoney(cost.monthlyHousing)}
                  <small> / 月</small>
                </strong>
                <span>首期现金 {formatMoney(cost.firstCash)}</span>
                <em>{cost.unknowns.length ? `${cost.unknowns.length} 项费用未知` : "费用均已确认"}</em>
              </>
            );
          }}
        />
        <DifferenceNote
          listings={listings}
          values={listings.map((listing) => calculateCosts(listing, task.expectedMonths).monthlyHousing)}
          unit="元 / 月"
        />
        <DetailRows
          labels={["月租", "月均固定费用", "不退一次性费用月均摊销", "首期预付租金", "押金与一次性费用"]}
          listings={listings}
          values={(listing) => {
            const cost = calculateCosts(listing, task.expectedMonths);
            return [
              formatMoney(listing.rent),
              formatMoney(cost.monthlyFees),
              `${formatMoney(cost.amortizedOneTime)}（按 ${task.expectedMonths} 个月）`,
              formatMoney(cost.prepaidRent),
              formatMoney(cost.firstCashExtras),
            ];
          }}
        />
      </section>
    );
  if (section === "commute")
    return (
      <section className="comparison-section">
        <SectionTitle icon={<ClockIcon />} title="通勤" subtitle={`单程到 ${task.commuteDestination}，支出单独显示`} />
        <MetricRail
          listings={listings}
          render={(listing) => (
            <>
              <strong>
                {listing.commuteMinutes ?? "?"}
                <small> 分钟</small>
              </strong>
              <span>
                {formatCommuteMode(listing.commuteMode)} · 单次支出{" "}
                {listing.commuteFare === undefined ? "未知" : formatMoney(listing.commuteFare)}
              </span>
              <em>
                {listing.commuteMinutes && listing.commuteMinutes > 40 ? "超过 40 分钟硬性条件" : "通勤条件无已知冲突"}
              </em>
            </>
          )}
        />
        <DifferenceNote listings={listings} values={listings.map((listing) => listing.commuteMinutes)} unit="分钟" />
      </section>
    );
  if (section === "conditions")
    return (
      <section className="comparison-section">
        <SectionTitle icon={<CheckCircledIcon />} title="条件" subtitle="先显示硬性冲突与未知" />
        {task.conditions
          .filter((condition) => condition.importance !== "ignored")
          .map((condition) => (
            <div className="condition-row" key={condition.id}>
              <div>
                <strong>{condition.name}</strong>
                <small>{condition.importance === "required" ? "硬性条件" : "偏好条件"}</small>
              </div>
              <div className="condition-results">
                {listings.map((listing) => (
                  <ResultBadge key={listing.id} result={listing.conditionResults[condition.id] ?? "unknown"} />
                ))}
              </div>
            </div>
          ))}
      </section>
    );
  return (
    <section className="comparison-section">
      <SectionTitle icon={<ExclamationTriangleIcon />} title="看房异常" subtitle="只记录发现的问题，未记录不代表正常" />
      {listings.map((listing) => {
        const issues = getInspectionIssues(listing);
        return (
          <article className="inspection-summary" key={listing.id}>
            <strong>{listing.name}</strong>
            <span>{issues.length ? `${issues.length} 个已记录问题` : "暂无已记录问题"}</span>
            {issues.map((issue) => (
              <p key={issue.id}>
                <ExclamationTriangleIcon /> {issue.name}
                {issue.note ? `：${issue.note}` : ""}
              </p>
            ))}
          </article>
        );
      })}
    </section>
  );
}

function MetricRail({ listings, render }: { listings: Listing[]; render: (listing: Listing) => React.ReactNode }) {
  return (
    <Carousel className="metric-carousel" contentClassName="metric-track" ariaLabel="指标对比">
      {listings.map((listing) => (
        <article className="metric-card" key={listing.id}>
          {render(listing)}
        </article>
      ))}
    </Carousel>
  );
}
function DifferenceNote({
  listings,
  values,
  unit,
}: {
  listings: Listing[];
  values: (number | undefined)[];
  unit: string;
}) {
  const known = values.filter((value): value is number => value !== undefined);
  if (known.length < 2) return <p className="difference-note">存在未知信息，暂不能计算差异。</p>;
  const min = Math.min(...known);
  const max = Math.max(...known);
  const winner = listings[values.indexOf(min)];
  return (
    <p className="difference-note">
      {winner.name} 此项少 {Math.round(max - min).toLocaleString("zh-CN")} {unit}
    </p>
  );
}
function DetailRows({
  labels,
  listings,
  values,
}: {
  labels: string[];
  listings: Listing[];
  values: (listing: Listing) => string[];
}) {
  return (
    <div className="detail-table">
      {labels.map((label, index) => (
        <div className="detail-row" key={label}>
          <strong>{label}</strong>
          {listings.map((listing) => (
            <span key={listing.id}>{values(listing)[index]}</span>
          ))}
        </div>
      ))}
    </div>
  );
}
function SectionTitle({ icon, title, subtitle }: { icon: React.ReactNode; title: string; subtitle: string }) {
  return (
    <header className="section-title">
      <span>{icon}</span>
      <div>
        <h2>{title}</h2>
        <p>{subtitle}</p>
      </div>
    </header>
  );
}
function ResultBadge({ result }: { result: ConditionResult }) {
  return (
    <span className={`result-badge ${result}`}>
      {result === "met" ? "满足" : result === "conflict" ? "冲突" : "未知"}
    </span>
  );
}

function ConditionsScreen({
  state,
  setState,
  onOpenListing,
}: {
  state: AppState;
  setState: React.Dispatch<React.SetStateAction<AppState>>;
  onOpenListing: (id: string) => void;
}) {
  const [name, setName] = useState("");
  const updateImportance = (id: string, importance: AppState["task"]["conditions"][number]["importance"]) =>
    setState((current) => ({
      ...current,
      task: {
        ...current.task,
        conditions: current.task.conditions.map((condition) =>
          condition.id === id ? { ...condition, importance } : condition,
        ),
      },
    }));
  return (
    <MobileScroll className="app-screen" key="conditions-screen">
      <main className="conditions-screen">
        <header className="simple-hero">
          <p className="eyebrow">你的判断标准</p>
          <h1>条件与看房</h1>
          <p>硬性条件优先暴露风险，偏好只用于整理。</p>
        </header>
        <section className="settings-group">
          <h2>基础条件</h2>
          {state.task.conditions.map((condition) => (
            <div className="setting-row" key={condition.id}>
              <span>
                <strong>{condition.name}</strong>
                <small>{condition.custom ? "自定义" : "中国大陆模板"}</small>
              </span>
              <select
                value={condition.importance}
                onChange={(event) => updateImportance(condition.id, event.target.value as typeof condition.importance)}
              >
                <option value="required">硬性</option>
                <option value="preferred">偏好</option>
                <option value="ignored">忽略</option>
              </select>
            </div>
          ))}
          <div className="inline-add">
            <KeyboardInput
              value={name}
              onChange={(event) => setName(event.target.value)}
              placeholder="添加自定义条件"
            />
            <button
              disabled={!name.trim()}
              onClick={() => {
                setState((current) => ({
                  ...current,
                  task: {
                    ...current.task,
                    conditions: [
                      ...current.task.conditions,
                      { id: crypto.randomUUID(), name: name.trim(), importance: "preferred", custom: true },
                    ],
                  },
                }));
                setName("");
              }}
            >
              <PlusIcon />
            </button>
          </div>
        </section>
        <section className="settings-group">
          <h2>看房记录</h2>
          <p className="group-help">默认无需证明一切正常，只记录异常。</p>
          {state.task.listings
            .filter((listing) => listing.status === "candidate")
            .map((listing) => (
              <button className="listing-row" key={listing.id} onClick={() => onOpenListing(listing.id)}>
                <span>
                  <strong>{listing.name}</strong>
                  <small>
                    {getInspectionIssues(listing).length} 个异常 ·{" "}
                    {listing.inspections.filter((item) => item.state === "unchecked").length} 项未检查
                  </small>
                </span>
                <ChevronRightIcon />
              </button>
            ))}
        </section>
      </main>
    </MobileScroll>
  );
}

function AddListingForm({ city, onSave }: { city: string; onSave: (listing: Listing) => void }) {
  const [name, setName] = useState("");
  const [listingCity, setListingCity] = useState(city);
  const [rentalType, setRentalType] = useState<Listing["rentalType"]>("entire");
  const [rent, setRent] = useState("");
  const [roomCount, setRoomCount] = useState("");
  const [screenshotId, setScreenshotId] = useState<string>();
  const [photoIds, setPhotoIds] = useState<string[]>([]);
  const [ocr, setOcr] = useState<OcrSuggestion>();
  const [ocrStatus, setOcrStatus] = useState("");
  const valid =
    name.trim() &&
    listingCity.trim() &&
    Number(rent) > 0 &&
    Number.isInteger(Number(roomCount)) &&
    Number(roomCount) > 0;
  const handlePhotos = async (files?: FileList) => {
    const selectedFiles = files ? Array.from(files) : [];
    if (!selectedFiles.length) return;
    try {
      const mediaIds = await Promise.all(selectedFiles.map((file) => saveMedia(file)));
      setScreenshotId(mediaIds[0]);
      setPhotoIds(mediaIds.slice(1));
    } catch {
      setOcrStatus("照片保存失败，请重新选择");
      return;
    }
    setOcrStatus("正在本地识别 0%");
    try {
      const suggestion = await recognizeListingScreenshot(selectedFiles[0], (progress) =>
        setOcrStatus(`正在本地识别 ${progress}%`),
      );
      setOcr(suggestion);
      setOcrStatus("识别完成，请确认建议");
    } catch {
      setOcrStatus("未能识别，截图已绑定，请手动填写");
    }
  };
  return (
    <form
      className="sheet-form"
      onSubmit={(event) => {
        event.preventDefault();
        if (!valid) return;
        onSave({
          ...createListing({
            name: name.trim(),
            city: listingCity.trim(),
            rentalType,
            rent: Number(rent),
            currency: "CNY",
          }),
          screenshotId,
          photoIds,
          roomCount: Number(roomCount),
        });
      }}
    >
      <Field label="房源名称 *">
        <KeyboardInput
          value={name}
          onChange={(event) => setName(event.target.value)}
          placeholder="例如：徐汇 · 一室一厅"
        />
      </Field>
      <div className="form-grid">
        <Field label="城市 *">
          <KeyboardInput value={listingCity} onChange={(event) => setListingCity(event.target.value)} />
        </Field>
        <Field label="租赁方式 *">
          <select value={rentalType} onChange={(event) => setRentalType(event.target.value as Listing["rentalType"])}>
            <option value="entire">整租</option>
            <option value="shared">合租</option>
          </select>
        </Field>
      </div>
      <div className="form-grid">
        <Field label="月租 *">
          <KeyboardInput
            inputMode="numeric"
            value={rent}
            onChange={(event) => setRent(event.target.value.replace(/\D/g, ""))}
            placeholder="7800"
          />
        </Field>
        <Field label="货币 *">
          <select value="CNY" disabled>
            <option>CNY · 人民币</option>
          </select>
        </Field>
      </div>
      <Field label="居室数 *">
        <KeyboardInput
          inputMode="numeric"
          value={roomCount}
          onChange={(event) => setRoomCount(event.target.value.replace(/\D/g, ""))}
          placeholder="例如：2"
        />
      </Field>
      <label className="upload-box">
        <ImageIcon />
        <span>
          <strong>{screenshotId ? `已保存 ${photoIds.length + 1} 张房源照片` : "保存房源照片"}</strong>
          <small>图片只在当前浏览器处理与保存</small>
        </span>
        <input
          type="file"
          accept="image/*"
          multiple
          onChange={(event) => handlePhotos(event.target.files ?? undefined)}
        />
      </label>
      {ocrStatus ? (
        <div className="ocr-status">
          <MagnifyingGlassIcon />
          <span>{ocrStatus}</span>
        </div>
      ) : null}
      {ocr ? (
        <div className="suggestion">
          <strong>识别建议</strong>
          <p>
            {ocr.city ?? "未识别城市"} · {ocr.rent ? `¥${ocr.rent}` : "未识别租金"}
          </p>
          <div>
            <button
              type="button"
              onClick={() => {
                if (ocr.city) setListingCity(ocr.city);
                if (ocr.rent) setRent(String(ocr.rent));
                setOcrStatus("已采用建议，保存后才参与比较");
              }}
            >
              采用建议
            </button>
            <button type="button" onClick={() => setOcr(undefined)}>
              忽略
            </button>
          </div>
        </div>
      ) : null}
      <button className="full-primary" disabled={!valid}>
        保存租赁方案
      </button>
    </form>
  );
}

function EliminateDecision({ listing, onConfirm }: { listing: Listing; onConfirm: (reason: string) => void }) {
  const [reason, setReason] = useState(listing.eliminationReason ?? "");
  return (
    <div className="sheet-form">
      <p className="group-help">{listing.name} 将退出当前比较，但不会被删除。</p>
      <Field label="淘汰原因（可选）">
        <KeyboardTextarea
          value={reason}
          onChange={(event) => setReason(event.target.value)}
          placeholder="例如：通勤超过硬性上限"
        />
      </Field>
      <button className="full-primary" onClick={() => onConfirm(reason)}>
        确认淘汰
      </button>
    </div>
  );
}

function ListingEditor({
  task,
  listing,
  onChange,
  onToggleFocus,
}: {
  task: AppState["task"];
  listing: Listing;
  onChange: (patch: Partial<Listing>) => void;
  onToggleFocus: () => void;
}) {
  const [costName, setCostName] = useState("");
  const [costAmount, setCostAmount] = useState("");
  const [costCadence, setCostCadence] = useState<Listing["costs"][number]["cadence"]>("monthly");
  const [costRefundable, setCostRefundable] = useState(false);
  const [inspectionName, setInspectionName] = useState("");
  const [photoStatus, setPhotoStatus] = useState("");
  const updateInspection = (id: string, patch: Partial<Listing["inspections"][number]>) =>
    onChange({ inspections: listing.inspections.map((item) => (item.id === id ? { ...item, ...patch } : item)) });
  const addPhoto = async (inspectionId: string, file?: File) => {
    if (!file) return;
    const id = await saveMedia(file);
    const item = listing.inspections.find((current) => current.id === inspectionId);
    if (item) updateInspection(inspectionId, { photoIds: [...item.photoIds, id].slice(0, 3) });
  };
  const addListingPhotos = async (files?: FileList) => {
    const selectedFiles = files ? Array.from(files) : [];
    if (!selectedFiles.length) return;
    try {
      const photoIds = await Promise.all(selectedFiles.map((file) => saveMedia(file)));
      onChange({ photoIds: [...(listing.photoIds ?? []), ...photoIds] });
      setPhotoStatus(`已保存 ${photoIds.length} 张房源照片`);
    } catch {
      setPhotoStatus("照片保存失败，请重新选择");
    }
  };
  return (
    <div className="sheet-form">
      <button className={listing.focused ? "focus-toggle active" : "focus-toggle"} onClick={onToggleFocus}>
        {listing.focused ? <StarFilledIcon /> : <PlusIcon />}
        {listing.focused ? "取消重点考虑" : "标记重点考虑"}
      </button>
      <section>
        <h3>基本信息</h3>
        <Field label="地址（可未知）">
          <KeyboardInput
            value={listing.address ?? ""}
            onChange={(event) => onChange({ address: event.target.value })}
            placeholder="稍后补充"
          />
        </Field>
        <div className="form-grid">
          <Field label={listing.rentalType === "shared" ? "私人空间面积" : "整套面积"}>
            <KeyboardInput
              inputMode="decimal"
              value={listing.area ?? ""}
              onChange={(event) =>
                onChange({
                  area: Number(event.target.value) || undefined,
                  areaScope: listing.rentalType === "shared" ? "private" : "whole",
                })
              }
              placeholder="未知"
            />
          </Field>
          <Field label="户型">
            <KeyboardInput
              value={listing.layout ?? ""}
              onChange={(event) => onChange({ layout: event.target.value })}
              placeholder="未知"
            />
          </Field>
        </div>
        <div className="form-grid">
          <Field label="楼层（可未知）">
            <KeyboardInput
              value={listing.floor ?? ""}
              onChange={(event) => onChange({ floor: event.target.value })}
              placeholder="例如：8 / 18 层"
            />
          </Field>
          <Field label="居室数">
            <KeyboardInput
              inputMode="numeric"
              value={listing.roomCount ?? ""}
              onChange={(event) => onChange({ roomCount: Number(event.target.value) || undefined })}
              placeholder="例如：2"
            />
          </Field>
        </div>
        <div className="form-grid">
          <Field label="单程通勤（分钟）">
            <KeyboardInput
              inputMode="numeric"
              value={listing.commuteMinutes ?? ""}
              onChange={(event) => onChange({ commuteMinutes: Number(event.target.value) || undefined })}
            />
          </Field>
          <Field label="单次通勤支出">
            <KeyboardInput
              inputMode="decimal"
              value={listing.commuteFare ?? ""}
              onChange={(event) => onChange({ commuteFare: Number(event.target.value) || undefined })}
            />
          </Field>
        </div>
        <Field label="通勤方式">
          <select
            value={listing.commuteMode ?? ""}
            onChange={(event) => onChange({ commuteMode: (event.target.value || undefined) as Listing["commuteMode"] })}
          >
            <option value="">待补充</option>
            {Object.entries(commuteModeLabels).map(([value, label]) => (
              <option key={value} value={value}>
                {label}
              </option>
            ))}
          </select>
        </Field>
        <label className="upload-box">
          <ImageIcon />
          <span>
            <strong>补充房源照片</strong>
            <small>当前已保存 {(listing.screenshotId ? 1 : 0) + (listing.photoIds?.length ?? 0)} 张</small>
          </span>
          <input
            type="file"
            accept="image/*"
            multiple
            onChange={(event) => addListingPhotos(event.target.files ?? undefined)}
          />
        </label>
        {photoStatus ? <p className="group-help">{photoStatus}</p> : null}
      </section>
      <section>
        <h3>真实成本</h3>
        <Field label="首期预付租金（月，可未知）">
          <KeyboardInput
            inputMode="numeric"
            value={listing.prepaidRentMonths ?? ""}
            onChange={(event) => {
              const months = Number(event.target.value);
              onChange({
                prepaidRentMonths:
                  event.target.value && Number.isFinite(months) ? Math.max(1, Math.round(months)) : undefined,
              });
            }}
            placeholder="例如：付三填 3"
          />
        </Field>
        {listing.costs.map((cost) => (
          <div className="cost-row" key={cost.id}>
            <button
              className={cost.confirmed ? "check active" : "check"}
              onClick={() =>
                onChange({
                  costs: listing.costs.map((item) =>
                    item.id === cost.id ? { ...item, confirmed: !item.confirmed } : item,
                  ),
                })
              }
            >
              {cost.confirmed ? <CheckCircledIcon /> : <QuestionMarkCircledIcon />}
            </button>
            <span>
              <strong>{cost.name}</strong>
              <small>{cost.cadence === "monthly" ? "每月" : cost.refundable ? "一次性 · 可退" : "一次性 · 不退"}</small>
            </span>
            <b>{cost.amount === undefined ? "未知" : formatMoney(cost.amount)}</b>
          </div>
        ))}
        <div className="inline-add three">
          <KeyboardInput
            value={costName}
            onChange={(event) => setCostName(event.target.value)}
            placeholder="费用名称"
          />
          <KeyboardInput
            inputMode="decimal"
            value={costAmount}
            onChange={(event) => setCostAmount(event.target.value.replace(/[^\d.]/g, ""))}
            placeholder="金额"
          />
          <button
            disabled={!costName.trim()}
            onClick={() => {
              const parsedAmount = Number(costAmount);
              const hasAmount = costAmount !== "" && Number.isFinite(parsedAmount) && parsedAmount >= 0;
              onChange({
                costs: [
                  ...listing.costs,
                  {
                    id: crypto.randomUUID(),
                    name: costName.trim(),
                    amount: hasAmount ? parsedAmount : undefined,
                    cadence: costCadence,
                    refundable: costCadence === "oneTime" && costRefundable,
                    confirmed: hasAmount,
                  },
                ],
              });
              setCostName("");
              setCostAmount("");
              setCostCadence("monthly");
              setCostRefundable(false);
            }}
          >
            <PlusIcon />
          </button>
        </div>
        <div className="cost-options">
          <select value={costCadence} onChange={(event) => setCostCadence(event.target.value as typeof costCadence)}>
            <option value="monthly">每月费用</option>
            <option value="oneTime">一次性费用</option>
          </select>
          <label>
            <input
              type="checkbox"
              checked={costRefundable}
              disabled={costCadence === "monthly"}
              onChange={(event) => setCostRefundable(event.target.checked)}
            />
            可退
          </label>
        </div>
      </section>
      <section>
        <h3>条件结果</h3>
        {task.conditions
          .filter((condition) => condition.importance !== "ignored")
          .map((condition) => (
            <div className="setting-row" key={condition.id}>
              <span>
                <strong>{condition.name}</strong>
                <small>{condition.importance === "required" ? "硬性" : "偏好"}</small>
              </span>
              <select
                value={listing.conditionResults[condition.id] ?? "unknown"}
                onChange={(event) =>
                  onChange({
                    conditionResults: {
                      ...listing.conditionResults,
                      [condition.id]: event.target.value as ConditionResult,
                    },
                  })
                }
              >
                <option value="unknown">未知</option>
                <option value="met">满足</option>
                <option value="conflict">冲突</option>
              </select>
            </div>
          ))}
      </section>
      <section>
        <h3>异常优先看房清单</h3>
        <p className="group-help">未记录不代表正常；发现问题时再展开备注和照片。</p>
        {listing.inspections
          .filter((item) => !item.hidden)
          .map((item) => (
            <div className={`inspection-editor ${item.state}`} key={item.id}>
              <div>
                <strong>{item.name}</strong>
                <button className="inspection-action" onClick={() => updateInspection(item.id, { hidden: true })}>
                  隐藏
                </button>
                <select
                  value={item.state}
                  onChange={(event) => updateInspection(item.id, { state: event.target.value as InspectionState })}
                >
                  <option value="unchecked">未检查</option>
                  <option value="okay">未发现问题</option>
                  <option value="issue">有问题</option>
                </select>
              </div>
              {item.state === "issue" ? (
                <>
                  <KeyboardTextarea
                    value={item.note}
                    onChange={(event) => updateInspection(item.id, { note: event.target.value })}
                    placeholder="只记录发现的问题…"
                  />
                  <label className="photo-button">
                    <ImageIcon /> 添加照片（{item.photoIds.length}/3）
                    <input
                      type="file"
                      accept="image/*"
                      onChange={(event) => addPhoto(item.id, event.target.files?.[0])}
                    />
                  </label>
                </>
              ) : null}
            </div>
          ))}
        {listing.inspections.some((item) => item.hidden) ? (
          <div className="hidden-inspections">
            <small>已隐藏</small>
            {listing.inspections
              .filter((item) => item.hidden)
              .map((item) => (
                <button key={item.id} onClick={() => updateInspection(item.id, { hidden: false })}>
                  恢复“{item.name}”
                </button>
              ))}
          </div>
        ) : null}
        <div className="inline-add">
          <KeyboardInput
            value={inspectionName}
            onChange={(event) => setInspectionName(event.target.value)}
            placeholder="添加自定义检查项"
          />
          <button
            disabled={!inspectionName.trim()}
            onClick={() => {
              onChange({
                inspections: [
                  ...listing.inspections,
                  {
                    id: crypto.randomUUID(),
                    name: inspectionName.trim(),
                    state: "unchecked",
                    note: "",
                    photoIds: [],
                    custom: true,
                  },
                ],
              });
              setInspectionName("");
            }}
          >
            <PlusIcon />
          </button>
        </div>
      </section>
    </div>
  );
}

function TaskEditor({
  state,
  setState,
  onCreateNew,
}: {
  state: AppState;
  setState: React.Dispatch<React.SetStateAction<AppState>>;
  onCreateNew: () => void;
}) {
  const task = state.task;
  const update = (patch: Partial<typeof task>) =>
    setState((current) => ({ ...current, task: { ...current.task, ...patch } }));
  return (
    <div className="sheet-form">
      <Field label="任务名称">
        <KeyboardInput value={task.title} onChange={(event) => update({ title: event.target.value })} />
      </Field>
      <div className="form-grid">
        <Field label="城市">
          <KeyboardInput value={task.city} onChange={(event) => update({ city: event.target.value })} />
        </Field>
        <Field label="地区模板">
          <select value={task.regionTemplate} disabled>
            <option>中国大陆</option>
          </select>
        </Field>
      </div>
      <div className="form-grid">
        <Field label="预计租期（月）">
          <KeyboardInput
            inputMode="numeric"
            value={task.expectedMonths}
            onChange={(event) => update({ expectedMonths: Math.max(1, Number(event.target.value) || 1) })}
          />
        </Field>
        <Field label="面积单位">
          <select disabled>
            <option>平方米</option>
          </select>
        </Field>
      </div>
      <Field label="通勤目的地">
        <KeyboardInput
          value={task.commuteDestination}
          onChange={(event) => update({ commuteDestination: event.target.value })}
        />
      </Field>
      <div className="privacy-callout">
        <HomeIcon />
        <p>
          <strong>数据仅保存在当前设备</strong>
          <br />
          没有账户、云同步或业务服务器。浏览器数据被清理后无法恢复。
        </p>
      </div>
      <button className="outline-button" onClick={onCreateNew}>
        <PlusIcon /> 创建新的选房任务
      </button>
    </div>
  );
}

function CompareManager({
  state,
  updateTask,
}: {
  state: AppState;
  updateTask: (transform: (task: AppState["task"]) => AppState["task"]) => void;
}) {
  const candidates = state.task.listings.filter((listing) => listing.status === "candidate");
  return (
    <div className="sheet-form">
      <p className="selection-count">已选择 {state.task.comparisonIds.length}/5 套</p>
      {candidates.map((listing) => {
        const included = state.task.comparisonIds.includes(listing.id);
        return (
          <div className="manage-row" key={listing.id}>
            <button
              className={included ? "selection-check active" : "selection-check"}
              onClick={() =>
                updateTask((task) => ({
                  ...task,
                  comparisonIds: included
                    ? task.comparisonIds.filter((id) => id !== listing.id)
                    : task.comparisonIds.length < 5
                      ? [...task.comparisonIds, listing.id]
                      : task.comparisonIds,
                }))
              }
            >
              {included ? <CheckCircledIcon /> : <PlusIcon />}
            </button>
            <img src={listing.imageUrl} alt="" />
            <span>
              <strong>{listing.name}</strong>
              <small>
                {listing.rentalType === "entire" ? "整租" : "合租"} · ¥{listing.rent.toLocaleString("zh-CN")}
              </small>
            </span>
            {included ? (
              <button
                className={state.task.baselineId === listing.id ? "baseline active" : "baseline"}
                onClick={() => updateTask((task) => ({ ...task, baselineId: listing.id }))}
              >
                {state.task.baselineId === listing.id ? "基准" : "设为比较基准"}
              </button>
            ) : null}
          </div>
        );
      })}
      <p className="group-help">基准只代表“其他房源与谁比较”，不代表推荐；不会自动使用重点房源。</p>
    </div>
  );
}

function FinalDecision({
  state,
  updateTask,
  onDone,
}: {
  state: AppState;
  updateTask: (transform: (task: AppState["task"]) => AppState["task"]) => void;
  onDone: () => void;
}) {
  const [listingId, setListingId] = useState(state.task.finalListingId ?? state.task.comparisonIds[0] ?? "");
  const [reason, setReason] = useState(state.task.finalReason ?? "");
  const [risksAcknowledged, setRisksAcknowledged] = useState(false);
  const listing = state.task.listings.find((item) => item.id === listingId);
  const risks = listing
    ? [
        ...getRequiredConflicts(state.task, listing).map((item) => item.name),
        ...calculateCosts(listing, state.task.expectedMonths).unknowns.map((name) => `${name}未知`),
        ...getInspectionIssues(listing).map((item) => `${item.name}有异常`),
      ]
    : [];
  return (
    <div className="sheet-form">
      <Field label="最终房源">
        <select value={listingId} onChange={(event) => setListingId(event.target.value)}>
          {state.task.listings
            .filter((item) => item.status === "candidate")
            .map((item) => (
              <option key={item.id} value={item.id}>
                {item.name}
              </option>
            ))}
        </select>
      </Field>
      <div className="risk-review">
        <strong>确认前再看风险</strong>
        {risks.length ? (
          risks.map((risk) => (
            <p key={risk}>
              <ExclamationTriangleIcon /> {risk}
            </p>
          ))
        ) : (
          <p>
            <CheckCircledIcon /> 暂无已记录硬性冲突或未知费用
          </p>
        )}
      </div>
      {risks.length ? (
        <label className="acknowledge-risk">
          <input
            type="checkbox"
            checked={risksAcknowledged}
            onChange={(event) => setRisksAcknowledged(event.target.checked)}
          />
          我已知晓以上未解决项，仍由我自主完成选择
        </label>
      ) : null}
      <Field label="我的选择理由">
        <KeyboardTextarea
          value={reason}
          onChange={(event) => setReason(event.target.value)}
          placeholder="为什么这套更适合我？"
        />
      </Field>
      <button
        className="full-primary"
        disabled={!listingId || !reason.trim() || (risks.length > 0 && !risksAcknowledged)}
        onClick={() => {
          updateTask((task) => ({
            ...task,
            finalListingId: listingId,
            finalReason: reason.trim(),
            completed: true,
            events: [
              ...task.events,
              {
                id: crypto.randomUUID(),
                type: "confirmed",
                listingId,
                reason: reason.trim(),
                at: new Date().toISOString(),
              },
            ],
          }));
          onDone();
        }}
      >
        由我确认最终房源
      </button>
    </div>
  );
}

function ResultSheet({
  state,
  onWithdraw,
  onFeedback,
}: {
  state: AppState;
  onWithdraw: () => void;
  onFeedback: () => void;
}) {
  const finalListing = state.task.listings.find((item) => item.id === state.task.finalListingId);
  const finalCosts = finalListing ? calculateCosts(finalListing, state.task.expectedMonths) : undefined;
  const finalConflicts = finalListing ? getRequiredConflicts(state.task, finalListing) : [];
  const finalIssues = finalListing ? getInspectionIssues(finalListing) : [];
  const eliminated = state.task.listings.filter((listing) => listing.status === "eliminated");
  return (
    <div className="result-sheet">
      {finalListing ? (
        <>
          <div className="result-hero">
            <CheckCircledIcon />
            <p>最终选择</p>
            <h2>{finalListing.name}</h2>
            <span>{state.task.finalReason}</span>
          </div>
          <div className="result-facts">
            <p>
              <strong>{formatMoney(calculateCosts(finalListing, state.task.expectedMonths).monthlyHousing)}</strong>
              <small>月均居住成本</small>
            </p>
            <p>
              <strong>{formatMoney(finalCosts?.firstCash)}</strong>
              <small>首期现金压力</small>
            </p>
            <p>
              <strong>{finalListing.commuteMinutes ?? "?"} 分钟</strong>
              <small>单程通勤</small>
            </p>
          </div>
          <section className="result-evidence">
            <h3>仍需留意</h3>
            {finalConflicts.length || finalIssues.length || finalCosts?.unknowns.length ? (
              <ul>
                {finalConflicts.map((condition) => (
                  <li key={condition.id}>硬性条件：{condition.name}</li>
                ))}
                {finalIssues.map((issue) => (
                  <li key={issue.id}>看房异常：{issue.name}</li>
                ))}
                {finalCosts?.unknowns.map((unknown) => (
                  <li key={unknown}>未确认：{unknown}</li>
                ))}
              </ul>
            ) : (
              <p>暂无已记录的硬性冲突、看房异常或未知费用。</p>
            )}
          </section>
        </>
      ) : (
        <p>尚未确认最终房源。</p>
      )}
      <section className="result-evidence">
        <h3>已淘汰方案</h3>
        {eliminated.length ? (
          eliminated.map((listing) => (
            <p key={listing.id}>
              <strong>{listing.name}</strong>
              <br />
              <small>{listing.eliminationReason || "未填写淘汰原因"}</small>
            </p>
          ))
        ) : (
          <p>暂无已淘汰方案。</p>
        )}
      </section>
      <div className="privacy-callout">
        <DownloadIcon />
        <p>
          <strong>导出不会包含原始图片</strong>
          <br />
          报告只包含你确认的结构化信息与文字记录。
        </p>
      </div>
      <button className="full-primary" onClick={() => downloadText("租房决策结果.html", buildDecisionReport(state))}>
        <DownloadIcon /> 导出决策结果
      </button>
      <button
        className="outline-button"
        onClick={() =>
          downloadText("本地测试摘要.json", JSON.stringify(buildTestSummary(state), null, 2), "application/json")
        }
      >
        <DownloadIcon /> 导出匿名测试摘要
      </button>
      <button className="outline-button" onClick={onFeedback}>
        反馈使用问题
      </button>
      {finalListing ? (
        <button className="danger-link" onClick={onWithdraw}>
          <ResetIcon /> 撤回选择并重新比较
        </button>
      ) : null}
    </div>
  );
}

function FeedbackForm({
  state,
  setState,
}: {
  state: AppState;
  setState: React.Dispatch<React.SetStateAction<AppState>>;
}) {
  const feedback = state.feedback;
  const setFeedback = (patch: Partial<typeof feedback>) =>
    setState((current) => ({ ...current, feedback: { ...current.feedback, ...patch } }));
  const fileRef = useRef<HTMLInputElement>(null);
  const attach = async (file?: File) => {
    if (!file) return;
    if (!window.confirm("确认主动附带这张截图吗？截图可能包含房源或个人信息。")) {
      if (fileRef.current) fileRef.current.value = "";
      return;
    }
    setFeedback({ screenshotId: await saveMedia(file), screenshotConfirmed: true });
  };
  const exportFeedback = async () => {
    const payload: Record<string, unknown> = {
      testId: feedback.testId,
      category: feedback.category,
      text: feedback.text,
    };
    if (feedback.screenshotId && feedback.screenshotConfirmed) {
      const blob = await loadMedia(feedback.screenshotId);
      payload.screenshot = blob ? "用户已单独确认附图，请从设备手动发送。" : "截图不可用";
    }
    downloadText("产品反馈.json", JSON.stringify(payload, null, 2), "application/json");
  };
  return (
    <div className="sheet-form">
      <Field label="问题类型">
        <select
          value={feedback.category}
          onChange={(event) => setFeedback({ category: event.target.value as typeof feedback.category })}
        >
          <option>操作问题</option>
          <option>信息不清</option>
          <option>功能建议</option>
          <option>其他</option>
        </select>
      </Field>
      <Field label="你的反馈">
        <KeyboardTextarea
          value={feedback.text}
          onChange={(event) => setFeedback({ text: event.target.value })}
          placeholder="只填写你愿意主动提交的内容…"
        />
      </Field>
      <p className="test-id">随机测试编号：{feedback.testId}</p>
      <label className="upload-box">
        <ImageIcon />
        <span>
          <strong>{feedback.screenshotConfirmed ? "已确认附带截图" : "可选：主动选择截图"}</strong>
          <small>选择后会再次确认</small>
        </span>
        <input ref={fileRef} type="file" accept="image/*" onChange={(event) => attach(event.target.files?.[0])} />
      </label>
      <button className="full-primary" disabled={!feedback.text.trim()} onClick={exportFeedback}>
        导出反馈草稿
      </button>
    </div>
  );
}

function PrivacyNotice({ onConfirm }: { onConfirm: () => void }) {
  return (
    <div className="privacy-overlay">
      <div className="privacy-card">
        <span>
          <HomeIcon />
        </span>
        <p className="eyebrow">本地优先</p>
        <h1>
          你的选房资料
          <br />
          只留在当前设备
        </h1>
        <p>没有账户、云同步或业务服务器。截图 OCR 在浏览器本地运行；浏览器数据被清理后可能无法恢复。</p>
        <button className="full-primary" onClick={onConfirm}>
          我知道了，开始整理
        </button>
      </div>
    </div>
  );
}
function BottomNav({ tab, onChange, compareCount }: { tab: Tab; onChange: (tab: Tab) => void; compareCount: number }) {
  return (
    <nav className="bottom-nav" aria-label="主导航">
      <button className={tab === "listings" ? "active" : ""} onClick={() => onChange("listings")}>
        <HomeIcon />
        <span>房源</span>
      </button>
      <button className={tab === "compare" ? "active" : ""} onClick={() => onChange("compare")}>
        <MixerHorizontalIcon />
        <span>对比</span>
        {compareCount ? <i>{compareCount}</i> : null}
      </button>
      <button className={tab === "conditions" ? "active" : ""} onClick={() => onChange("conditions")}>
        <CheckCircledIcon />
        <span>条件</span>
      </button>
    </nav>
  );
}
function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <label className="field">
      <span>{label}</span>
      {children}
    </label>
  );
}
function Toast({ message, onDone }: { message: string; onDone: () => void }) {
  useEffect(() => {
    const timer = window.setTimeout(onDone, 2400);
    return () => window.clearTimeout(timer);
  }, [onDone]);
  return <div className="toast">{message}</div>;
}
