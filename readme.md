# Calculation of elastic constants using energy-strain method - Implemented in Vaspkit
Author: Daniel Ocampo
Oct, 2026

Reference: [VASPKIT tutorials](https://vaspkit.com/tutorials.html), elastic-properties section.

> This workflow uses task **201** with `VPKIT.in` preprocessing/postprocessing controls. The current website wording has not been verified live.

## 1. Generate the strained structures

Start from a **well-relaxed equilibrium structure**. Prepare the VASP input files:

```text
POSCAR
INCAR
POTCAR
KPOINTS
```

Configure `VPKIT.in` for **preprocessing**—first line set to `1`—and select the appropriate dimensionality and strain sampling.

Use the following strains:

```text
-0.015  -0.010  -0.005  0.000  +0.005  +0.010  +0.015
```

Run:

```bash
vaspkit -task 201
```

VASPKIT generates the independent strain-mode folders, named `C*`, containing the individual strained cases.

## 2. Copy the submission scripts and run the calculations

Place `submit_job.sh` and `submit_jobs.sh` in the parent directory containing the `C*` folders.

Copy both scripts into **each `C*` folder**, then launch the submission script there:

```bash
for d in C*/; do
    cp submit_job.sh submit_jobs.sh "$d"

    (
        cd "$d" || exit
        chmod +x submit_job.sh submit_jobs.sh
        nohup ./submit_jobs.sh > log &
    )
done
```

This runs the following command in each strain-mode directory:

```bash
nohup ./submit_jobs.sh > log &
```

**Calculation requirements:**

- Keep the imposed strained lattice fixed; do not relax the cell back to equilibrium.
- For **relaxed-ion** elastic constants, relax internal atomic positions at fixed cell, typically with `ISIF = 2`.
- Use consistent, well-converged numerical settings across all cases.
- If using sequential `WAVECAR` restarts, follow two separate branches within each strain mode:

  ```text
  0.000 → +0.005 → +0.010 → +0.015
  0.000 → -0.005 → -0.010 → -0.015
  ```

## 3. Check that every strained calculation has finished

Before fitting, verify that:

- All required VASP output files are present.
- Electronic calculations have converged.
- Internal relaxations have converged, if performed.
- The energies vary smoothly with strain.

A completed submission script does **not** necessarily mean the VASP calculations have finished.

## 4. Extract the elastic constants

Return to the parent directory containing `VPKIT.in` and all `C*` folders.

Change the **first line of `VPKIT.in` from `1` to `2`** to select postprocessing, keeping the other settings consistent with preprocessing.

Run:

```bash
vaspkit -task 201
```

VASPKIT reads the calculated energies, fits the energy–strain relationships, and determines the elastic constants.

## 5. Inspect the results and mechanical stability

The main output file is:

```text
ELASTIC_TENSOR
```

For a **3D bulk material**, the elastic constants are reported in **GPa**.

VASPKIT assesses **elastic mechanical stability using the Born stability criteria** appropriate to the crystal symmetry. At zero external stress, these require the elastic stiffness matrix to be **positive definite**, equivalently having all positive eigenvalues.

- **Stable:** the calculated tensor satisfies the elastic stability criteria.
- **Unstable:** at least one criterion is violated.

This is an **elastic stability** test—not proof of phonon/dynamical stability. If a stability condition is only barely satisfied or violated, check convergence and sensitivity to the fitted strain range.