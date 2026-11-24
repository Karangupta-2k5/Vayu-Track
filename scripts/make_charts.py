import pandas as pd, matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
plt.rcParams.update({"font.family":"DejaVu Sans","font.size":10,"axes.spines.top":False,"axes.spines.right":False,"axes.titleweight":"bold","axes.titlesize":12})
R=lambda n: pd.read_csv(f"results/q{n:02d}.csv")
BLUE,RED,TEAL,GREY="#2563eb","#dc2626","#0f766e","#94a3b8"

# 1 Top-10 cities (Q3)
d=R(3).sort_values("avg_pm25")
fig,ax=plt.subplots(figsize=(7,4))
ax.barh(d.city,d.avg_pm25,color=RED)
for y,v in enumerate(d.avg_pm25): ax.text(v+0.8,y,f"{v:.1f}",va="center",fontsize=9)
ax.axvline(40,color="#334155",ls="--",lw=1); ax.text(40.8,9.45,"India annual limit (40)",fontsize=8,color="#334155")
ax.set_xlabel("Average PM2.5 (µg/m³), Aug 2022 – Oct 2026"); ax.set_title("Q3. The ten most polluted cities by average PM2.5"); ax.set_xlim(0,90)
fig.tight_layout(); fig.savefig("docs/charts/q03_top10_cities.png",dpi=200); plt.close()

# 2 Monthly cycle (Q9)
d=R(9)
fig,ax=plt.subplots(figsize=(7,3.8))
ax.bar(d.month_name,d.avg_pm25,color=[RED if v>=45 else BLUE if v>=30 else TEAL for v in d.avg_pm25])
ax.set_ylabel("Average PM2.5 (µg/m³)"); ax.set_title("Q9. National monthly PM2.5 cycle vs rainfall")
ax2=ax.twinx(); ax2.plot(d.month_name,d.avg_rain_mm,color="#0ea5e9",marker="o",lw=2); ax2.set_ylabel("Avg daily rain (mm)",color="#0ea5e9"); ax2.spines["right"].set_visible(True)
fig.tight_layout(); fig.savefig("docs/charts/q09_monthly_cycle.png",dpi=200); plt.close()

# 3 Heatmap region x season (Q8)
d=R(8).set_index("region")[["winter","summer","monsoon","post_monsoon"]]
fig,ax=plt.subplots(figsize=(6.5,3.6))
im=ax.imshow(d.values,cmap="YlOrRd",aspect="auto")
ax.set_xticks(range(4)); ax.set_xticklabels(["Winter","Summer","Monsoon","Post-Monsoon"]); ax.set_yticks(range(len(d))); ax.set_yticklabels(d.index)
for i in range(d.shape[0]):
    for j in range(d.shape[1]): ax.text(j,i,f"{d.values[i,j]:.1f}",ha="center",va="center",fontsize=10,color="black" if d.values[i,j]<65 else "white")
ax.set_title("Q8. Average PM2.5 (µg/m³) by region and season"); 
for s in ax.spines.values(): s.set_visible(False)
fig.colorbar(im,ax=ax,shrink=0.8); fig.tight_layout(); fig.savefig("docs/charts/q08_region_season_heatmap.png",dpi=200); plt.close()

# 4 Rain & wind bands (Q18,Q19)
r=R(18); w=R(19)
fig,axs=plt.subplots(1,2,figsize=(7.5,3.6))
axs[0].bar(range(len(r)),r.avg_pm25,color=BLUE); axs[0].set_xticks(range(len(r))); axs[0].set_xticklabels(["Dry","Light","Moderate","Heavy","V. heavy"],fontsize=8)
axs[0].set_title("Q18. By rainfall",fontsize=11); axs[0].set_ylabel("Avg PM2.5 (µg/m³)")
axs[1].bar(range(len(w)),w.avg_pm25,color=TEAL); axs[1].set_xticks(range(len(w))); axs[1].set_xticklabels(["Calm\n<10","Light\n10-20","Breezy\n20-30","Windy\n30+"],fontsize=8)
axs[1].set_title("Q19. By max wind (km/h)",fontsize=11)
for a,s in ((axs[0],r.avg_pm25),(axs[1],w.avg_pm25)):
    for i,v in enumerate(s): a.text(i,v+0.7,f"{v:.1f}",ha="center",fontsize=8)
fig.tight_layout(); fig.savefig("docs/charts/q18_19_rain_wind.png",dpi=200); plt.close()

# 5 Like-for-like YoY (Q10)
d=R(10)
fig,ax=plt.subplots(figsize=(6.5,3.4))
ax.bar(d.year.astype(str),d.avg_pm25,color=[BLUE,TEAL,BLUE,RED])
for i,(v,p) in enumerate(zip(d.avg_pm25,d.pct_days_above_naaqs_60)): ax.text(i,v+0.6,f"{v:.1f}\n({p:.1f}% days >60)",ha="center",fontsize=8.5)
ax.set_ylim(0,44); ax.set_ylabel("Avg PM2.5 (µg/m³)"); ax.set_title("Q10. Like-for-like PM2.5, 1 Jan – 30 Oct each year")
fig.tight_layout(); fig.savefig("docs/charts/q10_yoy_like_for_like.png",dpi=200); plt.close()
print("charts ok")
