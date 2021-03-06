/*
 * omap iommu: main structures
 *
 * Copyright (C) 2008-2009 Nokia Corporation
 *
 * Written by Hiroshi DOYU <Hiroshi.DOYU@nokia.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2 as
 * published by the Free Software Foundation.
 */

#ifndef __MACH_IOMMU_H
#define __MACH_IOMMU_H

#include <linux/list.h>

struct iotlb_entry {
	u32 da;
	u32 pa;
	u32 pgsz, prsvd, valid;
	union {
		u16 ap;
		struct {
			u32 endian, elsz, mixed;
		};
	};
};

struct iommu {
	const char	*name;
	struct module	*owner;
	void __iomem	*regbase;
	struct device	*dev;
	void		*isr_priv;

	unsigned int	refcount;
	struct mutex	iommu_lock;	/* global for this whole object */

	/*
	 * We don't change iopgd for a situation like pgd for a task,
	 * but share it globally for each iommu.
	 */
	u32		*iopgd;
	spinlock_t	page_table_lock; /* protect iopgd */
	int		nr_tlb_entries;

	struct list_head	mmap;
	struct mutex		mmap_lock; /* protect mmap */
	int (*isr)(struct iommu *obj, u32 da, u32 iommu_errs, void *priv);

	struct raw_notifier_head	notifier;

	u32 da_start;
	u32 da_end;
	struct iotlb_entry *tlbs_e;/* iommu tlbs context: saved area */
	struct platform_device *pdev;
	struct list_head event_list;
	spinlock_t event_lock;
};

struct cr_regs {
	union {
		struct {
			u16 cam_l;
			u16 cam_h;
		};
		u32 cam;
	};
	union {
		struct {
			u16 ram_l;
			u16 ram_h;
		};
		u32 ram;
	};
};

struct iommu_event_ntfy {
	u32     fd;
	struct eventfd_ctx *evt_ctx;
	struct list_head list;
};

struct iotlb_lock {
	short base;
	short vict;
};

/* architecture specific functions */
struct iommu_functions {
	u32 (*get_version)(struct iommu *obj);

	int (*enable)(struct iommu *obj);
	void (*disable)(struct iommu *obj);
	void (*set_twl)(struct iommu *obj, bool on);
	u32 (*fault_isr)(struct iommu *obj, u32 *ra);

	void (*tlb_read_cr)(struct iommu *obj, struct cr_regs *cr);
	void (*tlb_load_cr)(struct iommu *obj, struct cr_regs *cr);

	struct cr_regs *(*alloc_cr)(struct iommu *obj, struct iotlb_entry *e);
	int (*cr_valid)(struct cr_regs *cr);
	u32 (*cr_to_virt)(struct cr_regs *cr);
	void (*cr_to_e)(struct cr_regs *cr, struct iotlb_entry *e);
	ssize_t (*dump_cr)(struct iommu *obj, struct cr_regs *cr, char *buf);

	u32 (*get_pte_attr)(struct iotlb_entry *e);

	ssize_t (*dump_ctx)(struct iommu *obj, char *buf, ssize_t len);
};

enum {
	IOMMU_FAULT,
	IOMMU_CLOSE,
};

struct iommu_platform_data {
	const char *name;
	const char *oh_name;
	const int nr_tlb_entries;
	u32 da_start;
	u32 da_end;
	int irq;
	void __iomem *io_base;
};

/* IOMMU errors */
#define OMAP_IOMMU_ERR_TLB_MISS		(1 << 0)
#define OMAP_IOMMU_ERR_TRANS_FAULT	(1 << 1)
#define OMAP_IOMMU_ERR_EMU_MISS		(1 << 2)
#define OMAP_IOMMU_ERR_TBLWALK_FAULT	(1 << 3)
#define OMAP_IOMMU_ERR_MULTIHIT_FAULT	(1 << 4)

#if defined(CONFIG_ARCH_OMAP1)
#error "iommu for this processor not implemented yet"
#else
#include <plat/iommu2.h>
#endif

/*
 * utilities for super page(16MB, 1MB, 64KB and 4KB)
 */

#define iopgsz_max(bytes)			\
	(((bytes) >= SZ_16M) ? SZ_16M :		\
	 ((bytes) >= SZ_1M)  ? SZ_1M  :		\
	 ((bytes) >= SZ_64K) ? SZ_64K :		\
	 ((bytes) >= SZ_4K)  ? SZ_4K  :	0)

#define bytes_to_iopgsz(bytes)				\
	(((bytes) == SZ_16M) ? MMU_CAM_PGSZ_16M :	\
	 ((bytes) == SZ_1M)  ? MMU_CAM_PGSZ_1M  :	\
	 ((bytes) == SZ_64K) ? MMU_CAM_PGSZ_64K :	\
	 ((bytes) == SZ_4K)  ? MMU_CAM_PGSZ_4K  : -1)

#define iopgsz_to_bytes(iopgsz)				\
	(((iopgsz) == MMU_CAM_PGSZ_16M)	? SZ_16M :	\
	 ((iopgsz) == MMU_CAM_PGSZ_1M)	? SZ_1M  :	\
	 ((iopgsz) == MMU_CAM_PGSZ_64K)	? SZ_64K :	\
	 ((iopgsz) == MMU_CAM_PGSZ_4K)	? SZ_4K  : 0)

#define iopgsz_ok(bytes) (bytes_to_iopgsz(bytes) >= 0)

/*
 * global functions
 */
extern u32 iommu_arch_version(struct iommu *obj);

extern void iotlb_cr_to_e(struct cr_regs *cr, struct iotlb_entry *e);
extern u32 iotlb_cr_to_virt(struct cr_regs *cr);

extern int iommu_register_notifier(struct iommu *obj,
						struct notifier_block *nb);
extern int iommu_unregister_notifier(struct iommu *obj,
						struct notifier_block *nb);
extern int iommu_notify_event(struct iommu *obj, int event, void *data);

extern int load_iotlb_entry(struct iommu *obj, struct iotlb_entry *e);
extern void iommu_set_twl(struct iommu *obj, bool on);
extern void flush_iotlb_page(struct iommu *obj, u32 da);
extern void flush_iotlb_range(struct iommu *obj, u32 start, u32 end);
extern void flush_iotlb_all(struct iommu *obj);

extern int iopgtable_store_entry(struct iommu *obj, struct iotlb_entry *e);
extern void iopgtable_lookup_entry(struct iommu *obj, u32 da, u32 **ppgd,
				   u32 **ppte);
extern size_t iopgtable_clear_entry(struct iommu *obj, u32 iova);
extern void iopgtable_clear_entry_all(struct iommu *obj);

extern int iommu_set_da_range(struct iommu *obj, u32 start, u32 end);
extern struct iommu *iommu_get(const char *name);
extern void iommu_put(struct iommu *obj);
extern int iommu_set_isr(const char *name,
			 int (*isr)(struct iommu *obj, u32 da, u32 iommu_errs,
				    void *priv),
			 void *isr_priv);

u32 iommu_save_ctx(struct iommu *obj);
u32 iommu_restore_ctx(struct iommu *obj);
u32 iommu_save_tlb_entries(struct iommu *obj);
u32 iommu_restore_tlb_entries(struct iommu *obj);

extern int install_iommu_arch(const struct iommu_functions *ops);
extern void uninstall_iommu_arch(const struct iommu_functions *ops);

extern int foreach_iommu_device(void *data,
				int (*fn)(struct device *, void *));

extern ssize_t iommu_dump_ctx(struct iommu *obj, char *buf, ssize_t len);
extern size_t dump_tlb_entries(struct iommu *obj, char *buf, ssize_t len);
extern int iommu_get_plat_data_size(void);
#endif /* __MACH_IOMMU_H */
