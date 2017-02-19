#!/bin/bash
CONDAENV=jenkins-parmed-${PYTHON_VERSION}

# Load the appropriate modules. But the OS X build machine does not have modules (conda is in the
# path by default). So make sure this command never errors. If it failed on Linux, the very next
# conda command will fail due to a missing program
module load conda || true

# First remove the existing conda environment
conda remove -yn ${CONDAENV} --all || true

# Now create the conda environment
conda create -yn ${CONDAENV} --no-default-packages python=${PYTHON_VERSION}
conda config --add channels omnia
conda config --add channels ambermd

# Now add the packages we want
conda install -yn ${CONDAENV} numpy scipy pandas nose openmm coverage nose-timer \
                              python-coveralls ambermini=16.16 netCDF4
conda install -yn ${CONDAENV} pyflakes=1.0.0
conda install -yn ${CONDAENV} rdkit==2015.09.1 -c omnia
conda install -yn ${CONDAENV} boost==1.59.0 -c omnia
conda install -yn ${CONDAENV} nglview -c bioconda

# Add PyRosetta4 to the PYTHONPATH so it will be available
export PYTHONPATH=/usr/local/pyrosetta4/lib/python${PYTHON_VERSION}/site-packages

# Make sure we don't install pysander prereqs, since that is just ParmEd!
conda install -yn ${CONDAENV} --no-deps pysander

# Now enter this superamazingawesome environment we just created
source activate ${CONDAENV}

# Lint
echo "Checking the parmed source code with pyflakes"
sh devtools/ci/pyflakes_check.sh

# Now install ParmEd
python setup.py install

# Now run the tests
cd test

export AMBERHOME="`dirname \`which python\``/.."
./run_scripts.sh
coverage run --source=parmed --parallel-mode -m \
    nose -v --with-timer --timer-ok=5s --timer-warning=12s --timer-filter=warning,error .

coverage combine
coverage report -m
coverage xml -o ../coverage.xml
# Find the base directory of the report
basedir=`python -c "import os, parmed as pmd; print(os.path.split(os.path.split(pmd.__file__)[0])[0])"`
coveralls -b "$basedir" -y ../.coveralls.yml
