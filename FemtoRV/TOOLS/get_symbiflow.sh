# See: https://symbiflow-examples.readthedocs.io/en/latest/getting-symbiflow.html
# Prerequisites: apt install -y git wget xz-utils
# Set ARCH_DEFS_WEB according to https://symbiflow-examples.readthedocs.io/en/latest/getting-symbiflow.html

INSTALL_DIR=$HOME/opt/symbiflow
FPGA_FAM=xc7
ARCH_DEFS_WEB=https://storage.googleapis.com/symbiflow-arch-defs/artifacts/prod/foss-fpga-tools/symbiflow-arch-defs/continuous/install/367/20210822-000315


wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O conda_installer.sh
bash conda_installer.sh -u -b -p $INSTALL_DIR/$FPGA_FAM/conda;
. "$INSTALL_DIR/$FPGA_FAM/conda/etc/profile.d/conda.sh";
$INSTALL_DIR/$FPGA_FAM/conda/bin/conda env create -f $FPGA_FAM/environment.yml
mkdir -p $INSTALL_DIR/xc7/install

echo Getting arch defs
echo 1/5
wget -qO- $ARCH_DEFS_WEB/symbiflow-arch-defs-install-709cac78.tar.xz       | tar -xJC $INSTALL_DIR/xc7/install
echo 2/5
wget -qO- $ARCH_DEFS_WEB/symbiflow-arch-defs-xc7a50t_test-709cac78.tar.xz  | tar -xJC $INSTALL_DIR/xc7/install
echo 3/5
wget -qO- $ARCH_DEFS_WEB/symbiflow-arch-defs-xc7a100t_test-709cac78.tar.xz | tar -xJC $INSTALL_DIR/xc7/install
echo 4/5
wget -qO- $ARCH_DEFS_WEB/symbiflow-arch-defs-xc7a200t_test-709cac78.tar.xz | tar -xJC $INSTALL_DIR/xc7/install
echo 5/5
wget -qO- $ARCH_DEFS_WEB/symbiflow-arch-defs-xc7z010_test-709cac78.tar.xz  | tar -xJC $INSTALL_DIR/xc7/install

	
